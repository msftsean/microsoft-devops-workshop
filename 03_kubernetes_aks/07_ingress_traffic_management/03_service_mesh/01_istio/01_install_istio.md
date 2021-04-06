# Install Istio

Istio has components that run inside of the Kubernetes cluster, but it also has a client that should be installed locally.

Follow the directions on this page to find the appropriate binary for your system, using the latest version.

https://docs.microsoft.com/en-us/azure/aks/servicemesh-istio-install?pivots=client-operating-system-linux

At the latest revision of this document, the version is `1.8.2`

## Install the Istio Operator

Setup your KUBECONFIG file, for the target cluster, such that `kubectl get all --all-namespaces` connects to the appropriate cluster. The following command will install the istio operator onto that cluster.

```
istioctl operator init --hub docker.io/istio
```

Expected Output:
```
Installing operator controller in namespace: istio-operator using image: docker.io/istio/operator:1.8.2
Operator controller will watch namespaces: istio-system
✔ Istio operator installed                                                                                                                                                                                                                                                    
✔ Installation complete
```

You can also validate that the operator is running on the cluster by executing
```
kubectl get pods -n istio-operator
```

## Deploy Istio Service Mesh

In order to deploy the service mesh, we need to setup the configuration that instructs what features are in-use. Thankfully, istioctl provides some profiles from which we can base our configuration.

https://istio.io/latest/docs/setup/additional-setup/config-profiles/

Run the following command to get the default configuration printed out.
```
istioctl profile dump default
```

We can use this default configuration and define some overrides, when we setup the mesh.
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
  meshConfig:
    defaultConfig:
      proxyMetadata:
        ISTIO_META_DNS_CAPTURE: "true"
        ISTIO_META_PROXY_XDS_VIA_AGENT: "true"
  hub: docker.io/istio
  addonComponents:
    istiocoredns:
      enabled: false
  profile: default
  values:
    gateways:
      istio-ingressgateway:
        autoscaleEnabled: true
        type: LoadBalancer
        # Uncomment this, if youd like it to be internal load balancing ingress.
        # serviceAnnotations:
        #   service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    global:
      # Ensure that the Istio pods are only scheduled to run on Linux nodes
      defaultNodeSelector:
        beta.kubernetes.io/os: linux

      # Uncomment this, if you want to allow tcpdump on the proxy.
      # proxy:
      #   privileged: true
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
pod/istio-ingressgateway-6878d85997-v8txh   1/1     Running   0          31s
pod/istiocoredns-5b5d4d8b49-lzsqc           2/2     Running   0          31s
pod/istiod-69ff48c887-229gt                 1/1     Running   0          38s

NAME                           TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                                                                      AGE
service/istio-ingressgateway   LoadBalancer   10.100.52.77    <pending>     15021:31898/TCP,80:32624/TCP,443:30466/TCP,15012:32545/TCP,15443:30791/TCP   32s
service/istiocoredns           ClusterIP      10.100.60.106   <none>        53/UDP,53/TCP                                                                32s
service/istiod                 ClusterIP      10.100.62.94    <none>        15010/TCP,15012/TCP,443/TCP,15014/TCP                                        40s

NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/istio-ingressgateway   1/1     1            1           32s
deployment.apps/istiocoredns           1/1     1            1           32s
deployment.apps/istiod                 1/1     1            1           40s

NAME                                              DESIRED   CURRENT   READY   AGE
replicaset.apps/istio-ingressgateway-6878d85997   1         1         1       32s
replicaset.apps/istiocoredns-5b5d4d8b49           1         1         1       32s
replicaset.apps/istiod-69ff48c887                 1         1         1       40s

NAME                                                       REFERENCE                         TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/istio-ingressgateway   Deployment/istio-ingressgateway   <unknown>/80%   1         5         1          32s
horizontalpodautoscaler.autoscaling/istiocoredns           Deployment/istiocoredns           <unknown>/80%   1         5         1          32s
horizontalpodautoscaler.autoscaling/istiod                 Deployment/istiod                 <unknown>/80%   1         5         1          40s
```

Additionally, we can see what the operator logged during the installation:

```
kubectl logs -n istio-operator -l name=istio-operator -f
```

Expected Output:
```
2021-01-28T08:32:03.846927Z	info	installer	Creating EnvoyFilter/istio-system/tcp-stats-filter-1.7 (istio-control-plane/)
2021-01-28T08:32:03.869470Z	info	installer	Creating EnvoyFilter/istio-system/tcp-stats-filter-1.8 (istio-control-plane/)
2021-01-28T08:32:03.891153Z	info	installer	Creating ConfigMap/istio-system/istio (istio-control-plane/)
2021-01-28T08:32:03.903948Z	info	installer	Creating ConfigMap/istio-system/istio-sidecar-injector (istio-control-plane/)
2021-01-28T08:32:03.923524Z	info	installer	Creating MutatingWebhookConfiguration//istio-sidecar-injector (istio-control-plane/)
2021-01-28T08:32:03.938982Z	info	installer	Creating Deployment/istio-system/istiod (istio-control-plane/)
2021-01-28T08:32:03.958156Z	info	installer	Creating PodDisruptionBudget/istio-system/istiod (istio-control-plane/)
2021-01-28T08:32:03.995469Z	info	installer	Creating HorizontalPodAutoscaler/istio-system/istiod (istio-control-plane/)
2021-01-28T08:32:04.013481Z	info	installer	Creating Service/istio-system/istiod (istio-control-plane/)
- Processing resources for Istiod.
```
