# Deploy Sample Application

With the components properly installed, we can deploy some workloads to verify that metrics and tracing is established.

This first command will tell istio, that any pods in the default namespace, will need to have the envoy sidecar injected automatically.

https://istio.io/latest/docs/ops/configuration/mesh/injection-concepts/

```
kubectl label namespace default istio-injection=enabled
```

If you take a look at the contents of this yaml file, you will notice that its all vanilla kubernetes resources.
```
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/bookinfo/platform/kube/bookinfo.yaml
```

Running this command applies a yaml file, which contains a couple of new (Custom Resource Definitions) CRDs implemented by istio.
```
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/bookinfo/networking/bookinfo-gateway.yaml
```

What we want to do now, is get our istio ingress gateway ip address, by running the followig command:
```
kubectl get svc -n istio-system
```

Expected Output:
```
NAME                   TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)                                                                      AGE
istio-ingressgateway   LoadBalancer   10.0.80.117   65.52.112.75   15021:31501/TCP,80:30071/TCP,443:30434/TCP,15012:30717/TCP,15443:30669/TCP   4h32m
istiod                 ClusterIP      10.0.31.163   <none>         15010/TCP,15012/TCP,443/TCP,15014/TCP                                        4h32m
jaeger-collector       ClusterIP      10.0.78.243   <none>         14268/TCP,14250/TCP                                                          108m
kiali                  ClusterIP      10.0.146.68   <none>         20001/TCP,9090/TCP                                                           45m
tracing                ClusterIP      10.0.184.81   <none>         80/TCP                                                                       108m
zipkin                 ClusterIP      10.0.90.192   <none>         9411/TCP                                                                     108m
```

We can identify that our ingress ip is `65.52.112.75`, and at this point, we can test our application by visiting http://65.52.112.75/productpage

#### Generate some Load

Because Jaeger is configured with a 1% sampling rate, you need to send at least 100 requests, to see tracing information in kiali.

```
for i in $(seq 1 100); do curl -s -o /dev/null "http://65.52.112.75/productpage"; done
```

### Gateway

```
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: bookinfo-gateway
spec:
  selector:
    istio: ingressgateway # use istio default controller
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
```

### VirtualService

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: bookinfo
spec:
  hosts:
  - "*"
  gateways:
  - bookinfo-gateway
  http:
  - match:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    route:
    - destination:
        host: productpage
        port:
          number: 9080
```

## Enable mTLS

istio-default.mtls.yml
```
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
spec:
  mtls:
    mode: STRICT
```

`kubectl apply -f istio-default.mtls.yml`

### Validate

Start by opening up at least 2 terminals. In the first terminal, we will run the following commands to start getting a dump from the proxy wrapping the details service.

Note: You will need to adjust for your pod name, and you will also need to uncomment global.proxy.privileged in the istio operator config.

```
kubectl exec -it details-v1-558b8b4b76-sm8tt -c istio-proxy -- bash
```

From within the proxy, run the following to see a tcp dump on the details port.
```
sudo tcpdump dst port 9080  -A
```

In the other terminal, We can use the following command to deploy netshoot into the monitoring namespace, which wont get the sidecar injected.

```
kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot -n monitoring -- /bin/bash
```

And within netshoot, we can run the following and check the other terminal for the tcpdump output that resulted. We will also see our request rejected.
```
curl details.default:9080
```

Expected TCPDUMP output:
```
GET / HTTP/1.1
Host: details.default:9080
User-Agent: curl/7.71.1
Accept: */*
```

If you delete the peerauthentication or set it to PERMISSIVE, this call would be allowed, and you would see expected output.

`kubectl delete peerauthentication default`

What this means, is that when that mode is set to STRICT, only the envoy encrypted requests pass through to the service.

We can demonstrate by re-applying the peerauthentication to the cluster, if it was removed, and then deploying our netshoot container, into the default namespace and trying our same request using http.

`kubectl apply -f istio-default.mtls.yml`

`kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot -n default -- /bin/bash`

```
bash-5.0# curl details.default:9080
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">
<HTML>
  <HEAD><TITLE>Not Found</TITLE></HEAD>
  <BODY>
    <H1>Not Found</H1>
    `/' not found.
    <HR>
    <ADDRESS>
     WEBrick/1.6.0 (Ruby/2.7.1/2020-03-31) at
     details.default:9080
    </ADDRESS>
  </BODY>
</HTML>
```

If you are still following the tcpdump, that would show that the request was encrypted even though we used http from the app container.
