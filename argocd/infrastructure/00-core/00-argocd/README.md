# Argo CD

Argo CD is initially installed by the Ansible bootstrap. The
`application.yaml` in this directory then manages the Argo CD Helm release
itself with automated sync, pruning, and self-healing.

The Helm chart does not manage the existing Argo CD Secret
(`configs.secret.createSecret: false`). This preserves the admin password and
other credentials created by Ansible.

local test port forward
```
ssh -t \
  -L 8080:127.0.0.1:8080 \
  root@server-01 \
  'KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n argocd port-forward svc/argo-cd-argocd-server 8080:443 --address 127.0.0.1'
  ```
