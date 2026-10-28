# how to add new key

``` bash
# add key by accessing pod and usung openbao cli
kubectl exec -it openbao-0 -n openbao -- bao kv put secret/argocd/github-repo \
    type="git" \
    url="https://github.com/your-user/your-repo.git" \
    username="git" \
    password="GITHUB_PAT_YOUR_TOKEN_HERE"
```
