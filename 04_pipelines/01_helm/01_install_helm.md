# Install Helm

## Install the Helm Cli Tools

Helm comes with an additional command line tool, that functions similarly to kubectl, in that it is making calls against the kubernetes api.

You can retrieve the binary for your distribution, from their git release page:
https://github.com/helm/helm/releases

Or you can install it via package manager.

Homebrew users can use `brew install kubernetes-helm`.
Chocolatey users can use `choco install kubernetes-helm`.
GoFish users can use `gofish install helm`.

**Helm 3 does not work the exact same way, there is no more init step, and you can skip to the next section.**

* Miscellaneous helm commands:


The following command will add the stable chart repository, to your local system. You can see what charts are made available by checking here: https://github.com/helm/charts
```
$ helm repo add stable https://kubernetes-charts.storage.googleapis.com
```


```
$ helm repo update
```

Additional commands can be gleamed from their source!
https://docs.helm.sh/helm/#helm

## Install Helm v2 (deprecated) to Kubernetes

If you have RBAC enabled, and you should, you should create the following local file and then apply it.

```
$ cat << EOF > helm-tiller-sa.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
EOF
```

```
$ kubectl apply -f helm-tiller-sa.yml
$ helm init --service-account tiller
```

