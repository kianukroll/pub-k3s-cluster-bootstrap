# OpenBao initialisieren und unseal-en

Die Argo-CD-Application installiert OpenBao, initialisiert es aber nicht automatisch.
Die Initialisierung erzeugt sensible Unseal Keys und einen Initial Root Token. Diese
Werte dürfen nicht in Git, in Chat-Nachrichten oder in unverschlüsselten Logs
gespeichert werden.

## Voraussetzungen

Der OpenBao-Pod muss laufen:

```bash
kubectl get pods -n openbao
```

Der Pod heißt bei der aktuellen Standalone-Konfiguration normalerweise `openbao-0`.
Falls der Name abweicht, den tatsächlichen Pod-Namen in den folgenden Befehlen
verwenden.

## OpenBao initialisieren

Die Initialisierung muss nur einmal pro persistentem Datenspeicher ausgeführt
werden:

```bash
kubectl exec -it -n openbao openbao-0 -- \
  bao operator init \
  -key-shares=5 \
  -key-threshold=3
```

Der Befehl erzeugt fünf Unseal Keys und einen Initial Root Token. Alle Werte
sofort in einem geeigneten Passwortmanager oder einem anderen geschützten
Secret-Speicher ablegen. Die Ausgabe niemals committen oder in diese
Dokumentation eintragen.

## OpenBao unseal-en

Mindestens drei verschiedene Unseal Keys eingeben. Den folgenden Befehl
dreimal ausführen:

```bash
kubectl exec -it -n openbao openbao-0 -- bao operator unseal
```

Bei jeder Ausführung eine andere Unseal Key eingeben. Nach der dritten gültigen
Key sollte OpenBao entsiegelt sein.

## Status prüfen

```bash
kubectl exec -n openbao openbao-0 -- \
  bao status -format=json
```

Erwartete Werte:

```json
{
  "initialized": true,
  "sealed": false
}
```

Zusätzlich den Kubernetes-Pod prüfen:

```bash
kubectl get pods -n openbao
```

Der Pod sollte `1/1` und `Running` anzeigen.

## Nach einem Neustart

Mit Shamir-Sealing muss OpenBao nach einem Neustart erneut mit drei der fünf
Unseal Keys entsiegelt werden. Die Keys werden nicht im Kubernetes-Cluster
gespeichert.

Für einen unbeaufsichtigten Betrieb sollte später Auto-Unseal über einen
geeigneten KMS oder HSM eingerichtet werden. Die Unseal Keys und der Root Token
dürfen nicht als normale Git- oder Kubernetes-Konfigurationsdateien verwaltet
werden.

## Kubernetes-Auth für External Secrets

Der `ClusterSecretStore` verwendet die OpenBao-Kubernetes-Auth-Methode und die
Rolle `eso-role`. Diese Konfiguration ist nicht Teil des Helm-Charts und muss
nach der Initialisierung einmalig eingerichtet werden.

Zuerst den ServiceAccount des OpenBao-Pods ermitteln:

```bash
kubectl get pod openbao-0 -n openbao \
  -o jsonpath='{.spec.serviceAccountName}{"\n"}'
```

Dieser ServiceAccount benötigt die Berechtigung, Kubernetes-Token zu prüfen.
`<openbao-service-account>` durch den zuvor ermittelten Namen ersetzen:

```bash
kubectl create clusterrolebinding openbao-token-reviewer \
  --clusterrole=system:auth-delegator \
  --serviceaccount=openbao:<openbao-service-account>
```

Anschließend interaktiv mit dem Initial Root Token an OpenBao anmelden:

```bash
kubectl exec -it -n openbao openbao-0 -- bao login
```

Die Kubernetes-Auth-Methode aktivieren, falls sie noch nicht aktiviert ist:

```bash
kubectl exec -it -n openbao openbao-0 -- \
  bao auth enable kubernetes
```

Die Kubernetes-API-Verbindung konfigurieren:

```bash
kubectl exec -it -n openbao openbao-0 -- \
  bao write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token
```

Eine Policy mit Lesezugriff auf das benötigte KV-v2-Secret anlegen:

```bash
cat <<'EOF' | kubectl exec -i -n openbao openbao-0 -- bao policy write eso-policy -
path "secret/data/argocd/private-repo" {
  capabilities = ["read"]
}

path "secret/metadata/argocd/private-repo" {
  capabilities = ["read"]
}
EOF
```

Die Rolle für den External-Secrets-ServiceAccount anlegen:

```bash
kubectl exec -it -n openbao openbao-0 -- \
  bao write auth/kubernetes/role/eso-role \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=eso-policy \
  ttl=1h
```

Danach sollte der `ClusterSecretStore` erneut synchronisieren. Prüfen:

```bash
kubectl get clustersecretstore openbao
kubectl describe clustersecretstore openbao
kubectl get externalsecret -n argocd
```

Der Root Token wird nur für die Einrichtung benötigt und darf nicht in Git
gespeichert werden. Für den produktiven Betrieb sollte die OpenBao-Konfiguration
über einen geschützten Bootstrap-Prozess und nicht über Klartext-Kommandos in
Shell-History automatisiert werden.

## Fehler: `could not load backend configuration`

Dieser Fehler und `invalid role name "eso-role"` bedeuten typischerweise, dass
die Kubernetes-Auth-Methode noch nicht vollständig eingerichtet wurde. Die
Reihenfolge ist verbindlich: Auth-Methode aktivieren, Backend konfigurieren,
Policy anlegen, Rolle anlegen.

Nach einer interaktiven Anmeldung mit einem berechtigten OpenBao-Token prüfen:

```bash
kubectl exec -it -n openbao openbao-0 -- bao auth list

kubectl exec -it -n openbao openbao-0 -- \
  bao read auth/kubernetes/config

kubectl exec -it -n openbao openbao-0 -- \
  bao list auth/kubernetes/role
```

Falls `kubernetes/` fehlt, aktivieren:

```bash
kubectl exec -it -n openbao openbao-0 -- \
  bao auth enable kubernetes
```

Falls das Backend nicht konfiguriert ist, konfigurieren:

```bash
kubectl exec -it -n openbao openbao-0 -- \
  bao write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token
```

Policy und Rolle anlegen. Die Policy muss vor der Rolle existieren:

```bash
cat <<'EOF' | kubectl exec -i -n openbao openbao-0 -- bao policy write eso-policy -
path "secret/data/argocd/private-repo" {
  capabilities = ["read"]
}

path "secret/metadata/argocd/private-repo" {
  capabilities = ["read"]
}
EOF

```bash
kubectl exec -it -n openbao openbao-0 -- \
  bao write auth/kubernetes/role/eso-role \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=eso-policy \
  ttl=1h
```

Login mit dem tatsächlich verwendeten ServiceAccount testen:

```bash
kubectl create token external-secrets -n external-secrets | \
  kubectl exec -i -n openbao openbao-0 -- \
  bao write auth/kubernetes/login role=eso-role jwt=-
```

Bei erfolgreichem Login `ClusterSecretStore` und `ExternalSecret` erneut prüfen:

```bash
kubectl describe clustersecretstore openbao
kubectl get externalsecret -n argocd
```

## Ansible-Automatisierung

Die Rolle `openbao_bootstrap` kann die Kubernetes-Auth-Konfiguration
idempotent einrichten. Dafür den Root Token ausschließlich in einer
verschlüsselten Ansible-Vault-Variablen hinterlegen:

```yaml
openbao_auth_bootstrap_enabled: true
openbao_root_token: "<in Ansible Vault verschlüsselt>"
```

Danach den Playbook-Lauf mit Vault-Passwort ausführen:

```bash
ansible-playbook -i inventory/prod/hosts.yml site.yml \
  --tags openbao,security \
  --ask-vault-pass
```

Die Rolle ermittelt den OpenBao-ServiceAccount selbst, erstellt das
`system:auth-delegator`-Binding und legt Auth-Backend, Policy und `eso-role`
nur an, wenn sie fehlen. Unseal Keys und Root Token werden nicht ausgegeben;
für vollständig unbeaufsichtigten Betrieb ist Auto-Unseal über KMS oder HSM
erforderlich.
