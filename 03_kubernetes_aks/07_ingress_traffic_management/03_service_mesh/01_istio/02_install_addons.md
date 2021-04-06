# Install Addons

There are some Addons that istio supports, but as of 1.8, they are no longer bundled and must be installed / configured seperately.



## Install Prometheus / Grafana / Alertmanager

Prometheus is an open source tool that can be used to collect metrics, which can later be displayed with other tools like Grafana. The scraping capability of prometheus makes it a great solution for kubernetes. We can "annotate" pods (or their templates in various controllers) that are advertising metrics, and prometheus can leverage the kubernetes api to quickly determine which endpoints should be included in the scrape.

This can be installed to the cluster using helm.

https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

Setup a monitoring namespace, where we can deploy monitoring components.
```
kubectl create namespace monitoring
```


```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

istio-prometheus.yml
```
prometheus:
  enabled: true
  prometheusSpec:
    podMetadata:
      annotations: 
        sidecar.istio.io/inject: "false"
    image:
      repository: quay.io/prometheus/prometheus
      tag: v2.24.0

alertmanager:
  alertmanagerSpec:
    image:
      repository: quay.io/prometheus/alertmanager
      tag: v0.21.0

prometheusOperator:
  image:
    repository: quay.io/prometheus-operator/prometheus-operator
    tag: v0.45.0
  prometheusConfigReloaderImage:
    repository: quay.io/prometheus-operator/prometheus-config-reloader
    tag: v0.45.0
  admissionWebhooks:
    patch:
      image:
        repository: jettech/kube-webhook-certgen
        tag: v1.5.0

defaultRules:
  rules:
    etcd: false
    kubeScheduler: false
    kubeApiserver: false
    kubelet: false
    kubernetesSystem: false
    kubeApiserverSlos: false

kubeControllerManager:
  enabled: false

kubeEtcd:
  enabled: false

kubeScheduler:
  enabled: false

coreDns:
  enabled: false

grafana:
  image:
    repository: docker.io/grafana/grafana
    tag: 7.3.5
  testFramework:
    image: "docker.io/bats/bats"
    tag: "v1.1.0"
  downloadDashboardsImage:
    repository: docker.io/curlimages/curl
    tag: 7.73.0
  initChownData:
    image:
      repository: docker.io/busybox
      tag: "1.31.1"
  sidecar:
    image:
      repository: quay.io/kiwigrid/k8s-sidecar
      tag: 1.10.7
      sha: ""
  imageRenderer:
    image:
      repository: docker.io/grafana/grafana-image-renderer
      tag: latest
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - disableDeletion: false
        folder: istio
        name: istio
        options:
          path: /var/lib/grafana/dashboards/istio
        orgId: 1
        type: file
      - disableDeletion: false
        folder: istio
        name: istio-services
        options:
          path: /var/lib/grafana/dashboards/istio-services
        orgId: 1
        type: file

  extraConfigmapMounts:
  - name: dashboards-istio
    mountPath: /var/lib/grafana/dashboards/istio
    configMap: istio-grafana-dashboards
    readOnly: true
  - name: dashboards-istio-services
    mountPath: /var/lib/grafana/dashboards/istio-services
    configMap: istio-services-grafana-dashboards
    readOnly: true

```

Before we install this chart, we need to create the configmaps which hold the json for the latest istio grafana dashboards.

```
kubectl apply -f samples/istio-grafana-dashboards.yml -n monitoring
```

```
helm upgrade --install kube-prometheus-stack -n monitoring prometheus-community/kube-prometheus-stack -f istio-prometheus.yml
```

This command installs the operator, and sets up an initial prometheus instance in the monitoring namespace.

This additional Pod and Service monitor spec, will be necessary to connect prometheus to istio, note that we are deploying these to the monitoring namespace.

https://github.com/istio/istio/blob/release-1.8/samples/addons/extras/prometheus-operator.yaml

*Note:* It's important the the service and pod monitor match the appropriate selector for your prometheus installation. We can find this on the initial prometheus installation by running the following command.

```
kubectl get prometheus -n monitoring kube-prometheus-stack-prometheus -o yaml | grep -A2 serviceMonitorSelector
```

Expected Output:
```
        f:serviceMonitorSelector:
          .: {}
          f:matchLabels:
--
  serviceMonitorSelector:
    matchLabels:
      release: kube-prometheus-stack
```

Based on this output, our monitors should include the label `release=kube-prometheus-stack`. The following pod monitor will allow us to have prometheus scrape based on specific annotations, as well as the istiod service itself.

istio-monitor.yml
```
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: envoy-stats-monitor
  labels:
    monitoring: istio-proxies
    release: kube-prometheus-stack
spec:
  selector:
    matchExpressions:
    - {key: istio-prometheus-ignore, operator: DoesNotExist}
  namespaceSelector:
    any: true
  jobLabel: envoy-stats
  podMetricsEndpoints:
  - path: /stats/prometheus
    interval: 15s
    relabelings:
    - action: keep
      sourceLabels: [__meta_kubernetes_pod_container_name]
      regex: "istio-proxy"
    - action: keep
      sourceLabels: [__meta_kubernetes_pod_annotationpresent_prometheus_io_scrape]
    - sourceLabels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
      action: replace
      regex: ([^:]+)(?::\d+)?;(\d+)
      replacement: $1:$2
      targetLabel: __address__
    - action: labeldrop
      regex: "__meta_kubernetes_pod_label_(.+)"
    - sourceLabels: [__meta_kubernetes_namespace]
      action: replace
      targetLabel: namespace
    - sourceLabels: [__meta_kubernetes_pod_name]
      action: replace
      targetLabel: pod_name
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istio-component-monitor
  labels:
    monitoring: istio-components
    release: kube-prometheus-stack
spec:
  jobLabel: istio
  targetLabels: [app]
  selector:
    matchExpressions:
    - {key: istio, operator: In, values: [pilot]}
  namespaceSelector:
    any: true
  endpoints:
  - port: http-monitoring
    interval: 15s
```

```
kubectl apply -f istio-monitor.yml -n monitoring
```

With the pod monitor above, we can now specify in our pod template parameters for prometheus to scrape. For Example:

```
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: true   # determines if a pod should be scraped. Set to true to enable scraping.
        prometheus.io/path: /metrics # determines the path to scrape metrics at. Defaults to /metrics.
        prometheus.io/port: 80       # determines the port to scrape metrics at. Defaults to 80.
```

To validate the service health you can run and validate that resources exist and are healthy.

```
kubectl get all -n monitoring
kubectl get servicemonitor -n monitoring
kubectl get podmonitor -n monitoring
```

Check Out Grafana Dashboard (navigate to localhost:8080):

You can find the default `admin` password here: https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml

```
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 8080:80
```

Check Out Prometheus Dashboard (navigate to localhost:9090):
```
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090 9090
```

Check Out Alertmanager Dashboard (navigate to localhost:9093)
```
kubectl port-forward svc/kube-prometheus-stack-alertmanager -n monitoring 9093 9093
```


## Install Jaeger

`kubectl apply -f https://raw.githubusercontent.com/istio/istio/master/samples/addons/jaeger.yaml -n istio-system`

If you are using a private registry, download the appropriate image, modify and run the following command:
```
kubectl patch deployment jaeger --patch '{"spec": {"template": {"spec": {"containers": [{"name": "jaeger","image": "docker.io/jaegertracing/all-in-one:1.20"}]}}}}' -n istio-system
```

Check Out Jaeger Dashboard (navigate to localhost:8081)
```
kubectl port-forward svc/tracing -n istio-system 8081:80
```

## Install Kiali

```
kubectl create namespace kiali-operator
```

```
helm upgrade --install \
    --set cr.create=false \
    --set image.repo=quay.io/kiali/kiali-operator \
    --set image.tag=v1.32.0 \
    --namespace kiali-operator \
    --repo https://kiali.org/helm-charts \
    --version 1.32.0 \
    kiali-operator \
    kiali-operator
```

istio-kiali.yml
```
apiVersion: kiali.io/v1alpha1
kind: Kiali
metadata:
  name: kiali
  annotations:
    ansible.operator-sdk/verbosity: "1"
spec:
  deployment:
    image_name: jmeisnertestaks.azurecr.io/kiali/kiali
    image_version: v1.32.0
  istio_component_namespaces:
    prometheus: monitoring
    grafana: monitoring
  istio_namespace: istio-system
  auth:
    strategy: anonymous
  deployment:
    pod_annotations:
      sidecar.istio.io/inject: "false"
  external_services:
    tracing:
      in_cluster_url: 'http://tracing.istio-system/jaeger'
    prometheus:
      url: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/
      custom_metrics_url: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/
```

`kubectl apply -f istio-kiali.yml -n istio-system`

Whenever you make changes and re-apply this resource, you should restart the current deployment.

`kubectl rollout restart deployment/kiali -n istio-system`


Check Out Kiali Dashboard (navigate to localhost:20001):
```
kubectl port-forward svc/kiali -n istio-system 20001 20001
```


