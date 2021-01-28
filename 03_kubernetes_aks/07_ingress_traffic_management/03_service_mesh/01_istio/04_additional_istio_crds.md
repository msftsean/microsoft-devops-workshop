# Additional Istio CRDs

https://istio.io/latest/docs/reference/config/networking/

### ServiceEntry

ServiceEntry will require the coredns istio integration, and is primarily used to map external services to internal endpoints.

https://istio.io/latest/docs/reference/config/networking/service-entry/

```
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-svc-https
spec:
  hosts:
  - api.dropboxapi.com
  - www.googleapis.com
  - api.facebook.com
  location: MESH_EXTERNAL
  ports:
  - number: 443
    name: https
    protocol: TLS
  resolution: DNS
```

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

### DestinationRule

DestinationRule defines policies that apply to traffic intended for a service after routing has occurred. These rules specify configuration for load balancing, connection pool size from the sidecar, and outlier detection settings to detect and evict unhealthy hosts from the load balancing pool.

https://istio.io/latest/docs/reference/config/networking/destination-rule/

```
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: bookinfo-ratings
spec:
  host: ratings.prod.svc.cluster.local
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN
```