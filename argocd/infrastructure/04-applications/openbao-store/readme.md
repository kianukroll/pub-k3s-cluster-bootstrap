# Adding Keys and Secrets

## Add a Git Repository Secret

1. Open a shell in the OpenBao pod:

```bash
kubectl exec -it openbao-0 -n openbao -- sh
```

2. Log in with the root token:

```bash
bao login <OPENBAO_ROOT_TOKEN>
```

3. Store the repository credentials in OpenBao:

```bash
kubectl exec -it openbao-0 -n openbao -- bao kv put secret/argocd/k3s-cluster \
    type="git" \
    url="https://github.com/kianukroll/k3s-cluster.git" \
    username="git" \
    password="GITHUB_PAT"
```

## Useful Commands

Enable the `secret/` KV-v2 secrets engine if it has not been enabled yet:

```bash
bao secrets enable -path=secret kv-v2
```

List the active secret engines and their mount paths:

```bash
bao secrets list
```

List secrets under the `secret/argocd/` path:

```bash
bao kv list secret/argocd/
```

Read a specific secret:

```bash
bao kv get secret/argocd/k3s-cluster
```

## Configure External Secrets Operator

Create the root-token Kubernetes Secret for development only. Do not use this approach in production:

```bash
kubectl create secret generic openbao-root-token \
  --namespace external-secrets \
  --from-literal=token="<OPENBAO_ROOT_TOKEN>"
```

Create a policy that allows ESO to read the Argo CD secrets:

```bash
kubectl exec -i openbao-0 -n openbao -- bao policy write eso-policy - <<EOF
path "secret/data/argocd/*" { capabilities = ["read"] }
EOF
```

Bind the policy to the ESO ServiceAccount:

```bash
kubectl exec -it openbao-0 -n openbao -- bao write auth/kubernetes/role/eso-role \
    bound_service_account_names=external-secrets \
    bound_service_account_namespaces=external-secrets \
    policies=eso-policy \
    ttl=1h
```
