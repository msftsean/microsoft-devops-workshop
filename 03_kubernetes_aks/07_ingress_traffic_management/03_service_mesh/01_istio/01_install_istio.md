# Install Istio

Istio has components that run inside of the Kubernetes cluster, but it also has a client that should be installed locally.

Follow the directions on this page to find the appropriate binary for your system.

https://docs.microsoft.com/en-us/azure/aks/servicemesh-istio-install?pivots=client-operating-system-linux

## Install the Istio Operator

Setup your KUBECONFIG file, for the target cluster, such that `kubectl get all --all-namespaces` connects to the appropriate cluster. The following command will install the istio operator onto that cluster.

```
istioctl operator init
```

Expected Output:
```
Using operator Deployment image: docker.io/istio/operator:1.7.3
✔ Istio operator installed                                                                                                                                                                                                                                                    
✔ Installation complete
```

You can also validate that the operator is running on the cluster by executing
```
kubectl get pods -n istio-operator
```

## Deploy Istio Service Mesh

Create the following file in the same location, where istioctl was installed.

istio.aks.yml
```
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
  name: istio-control-plane
spec:
  # Use the default profile as the base
  # More details at: https://istio.io/docs/setup/additional-setup/config-profiles/
  profile: default
  # Enable the addons that we will want to use
  addonComponents:
    grafana:
      enabled: true
    prometheus:
      enabled: true
    tracing:
      enabled: true
    kiali:
      enabled: true
  values:
    global:
      # Ensure that the Istio pods are only scheduled to run on Linux nodes
      defaultNodeSelector:
        beta.kubernetes.io/os: linux
    kiali:
      dashboard:
        auth:
          strategy: anonymous 
```

The above definition is leveraging the extension to the API, that the Istio operator provides. In this case, we are creating an IstioOperator object, which has details about the mesh we want to install onto the cluster. In more advanced, but uncommon use cases, you could have multiple service meshes defined for a single cluster, represented by multiple IstioOperator objects. There is a link to supported config profiles for a deeper look into the options available.

In order to setup the mesh, we will run the following commands to setup the namespace and apply the object.

```
kubectl create namespace istio-system
kubectl apply -f istio.aks.yml
kubectl get all -n istio-system
```

If all three commands are successful, the output should contain the control plane components and look similar to the following:
```
NAME                                        READY   STATUS    RESTARTS   AGE
pod/grafana-94dc6c584-rn4vb                 1/1     Running   0          2m38s
pod/istio-ingressgateway-5d795cc47f-ddjgq   1/1     Running   0          3m10s
pod/istio-tracing-85849cbd5f-j6hnm          1/1     Running   0          2m37s
pod/istiod-5c6b7b5b8f-9vxjw                 1/1     Running   0          3m23s
pod/kiali-bb4d5579d-xrg8m                   1/1     Running   0          2m37s
pod/prometheus-66c98799dc-68sgn             1/1     Running   0          2m37s

NAME                                TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)                                                      AGE
service/grafana                     ClusterIP      10.100.51.136   <none>         3000/TCP                                                     2m39s
service/istio-ingressgateway        LoadBalancer   10.100.59.132   34.94.174.31   15021:30137/TCP,80:30837/TCP,443:32250/TCP,15443:30654/TCP   3m10s
service/istiod                      ClusterIP      10.100.63.16    <none>         15010/TCP,15012/TCP,443/TCP,15014/TCP,853/TCP                3m24s
service/jaeger-agent                ClusterIP      None            <none>         5775/UDP,6831/UDP,6832/UDP                                   2m39s
service/jaeger-collector            ClusterIP      10.100.49.52    <none>         14267/TCP,14268/TCP,14250/TCP                                2m39s
service/jaeger-collector-headless   ClusterIP      None            <none>         14250/TCP                                                    2m38s
service/jaeger-query                ClusterIP      10.100.54.87    <none>         16686/TCP                                                    2m38s
service/kiali                       ClusterIP      10.100.61.148   <none>         20001/TCP                                                    2m38s
service/prometheus                  ClusterIP      10.100.48.95    <none>         9090/TCP                                                     2m38s
service/tracing                     ClusterIP      10.100.48.151   <none>         80/TCP                                                       2m38s
service/zipkin                      ClusterIP      10.100.56.44    <none>         9411/TCP                                                     2m38s

NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/grafana                1/1     1            1           2m39s
deployment.apps/istio-ingressgateway   1/1     1            1           3m12s
deployment.apps/istio-tracing          1/1     1            1           2m39s
deployment.apps/istiod                 1/1     1            1           3m25s
deployment.apps/kiali                  1/1     1            1           2m39s
deployment.apps/prometheus             1/1     1            1           2m39s

NAME                                              DESIRED   CURRENT   READY   AGE
replicaset.apps/grafana-94dc6c584                 1         1         1       2m39s
replicaset.apps/istio-ingressgateway-5d795cc47f   1         1         1       3m12s
replicaset.apps/istio-tracing-85849cbd5f          1         1         1       2m39s
replicaset.apps/istiod-5c6b7b5b8f                 1         1         1       3m25s
replicaset.apps/kiali-bb4d5579d                   1         1         1       2m39s
replicaset.apps/prometheus-66c98799dc             1         1         1       2m39s

NAME                                                       REFERENCE                         TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/istio-ingressgateway   Deployment/istio-ingressgateway   3%/80%    1         5         1          3m11s
horizontalpodautoscaler.autoscaling/istiod                 Deployment/istiod                 1%/80%    1         5         1          3m25s
```

Additionally, we can see what the operator logged during the installation:

```
kubectl logs -n istio-operator -l name=istio-operator -f
```

Expected Output:
```
2021-01-27T23:44:01.055571Z	info	installer	creating resource: Service/istio-system/jaeger-query
2021-01-27T23:44:01.105538Z	info	installer	creating resource: Service/istio-system/kiali
2021-01-27T23:44:01.152529Z	info	installer	creating resource: Service/istio-system/prometheus
2021-01-27T23:44:01.192335Z	info	installer	creating resource: Service/istio-system/tracing
2021-01-27T23:44:01.228173Z	info	installer	creating resource: Service/istio-system/zipkin
- Processing resources for Addons.
- Processing resources for Addons. Waiting for Deployment/istio-system/grafana, Deployment/istio-...
- Processing resources for Addons. Waiting for Deployment/istio-system/kiali, Deployment/istio-sy...
- Processing resources for Addons. Waiting for Deployment/istio-system/kiali
✔ Addons installed
```
