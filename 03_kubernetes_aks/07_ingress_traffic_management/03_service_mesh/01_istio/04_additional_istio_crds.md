# Additional Istio CRDs

https://istio.io/latest/docs/reference/config/networking/

https://github.com/istio/istio/tree/master/samples/bookinfo/networking

### DestinationRule

DestinationRule defines policies that apply to traffic intended for a service after routing has occurred. These rules specify configuration for load balancing, connection pool size from the sidecar, and outlier detection settings to detect and evict unhealthy hosts from the load balancing pool.

https://istio.io/latest/docs/reference/config/networking/destination-rule/

```
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: bookinfo-ratings
spec:
  host: ratings.default.svc.cluster.local
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN
```

```
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  trafficPolicy:
    loadBalancer:
      simple: RANDOM
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
```

### VirtualService

https://istio.io/latest/docs/reference/config/networking/virtual-service/

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
    - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 50
    - destination:
        host: reviews
        subset: v3
      weight: 50
```

### ServiceEntry

ServiceEntry will require the coredns istio integration, and is primarily used to map external services to internal endpoints. This requires the istio coredns feature enabled.

istio-dns-enabled.aks.yml
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
  values:
    global:
      # Ensure that the Istio pods are only scheduled to run on Linux nodes
      defaultNodeSelector:
        beta.kubernetes.io/os: linux
      # Uncomment this, if you want to allow tcpdump on the proxy.
      proxy:
        privileged: true

  # This block enables istio coredns to accept entries, for addresses outside of the cluster.
  addonComponents:
    istiocoredns:
      enabled: true

  # This block is going to enable envoy logging (NOT RECOMMENDED FOR PRODUCTION)
  # kubectl logs -f <podName> -n <podNamespace> -c istio-proxy
  meshConfig:
    accessLogFile: /dev/stdout

```

```
kubectl apply -f istio-dns-enabled.aks.yml
```

Retrieve the new DNS server ip address.
```
kubectl get svc -n istio-system istiocoredns -o jsonpath={.spec.clusterIP}
```

Stub it into the native Kubernetes DNS solution, for AKS, this is CoreDNS as well.
```
kubectl edit configmaps -n kube-system coredns -o yaml
```

```
kind: ConfigMap
apiVersion: v1
data:
  Corefile: |                        
    global:53 {
        errors
        cache 30
        forward . "10.0.174.147:53"
    }
    .:53 {
        errors
        health
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           upstream
           fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
```


https://istio.io/latest/docs/reference/config/networking/service-entry/

```
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-svc-dns
spec:
  hosts:
  - foo.bar.com
  location: MESH_EXTERNAL
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
  endpoints:
  - address: us.foo.bar.com
    ports:
      https: 8080
  - address: uk.foo.bar.com
    ports:
      https: 9080
  - address: in.foo.bar.com
    ports:
      https: 7080
```

Calls from the application to http://foo.bar.com will be load balanced across the three domains specified above.

### PeerAuthentication

PeerAuthentication defines how traffic will be tunneled (or not) to the sidecar.

https://istio.io/latest/docs/reference/config/security/peer_authentication/

```
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
spec:
  mtls:
    mode: STRICT
```
