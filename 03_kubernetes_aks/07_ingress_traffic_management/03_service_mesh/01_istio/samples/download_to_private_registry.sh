# Prior to running this script, you should have access to the Azure Registry AND the docker.io registry.
# You should also connect to Azure, and login to the private registry.
PRIVATE_REPO=jmeisnertestaks.azurecr.io

import_image () {

	# First arg is the hub url, such as docker.io
	# Second arg is the repository, such as istio
	# Third arg is the image with the appropriate tag, such as operator:1.8.2

	docker pull $1/$2/$3
	docker tag $1/$2/$3 $PRIVATE_REPO/$2/$3
	docker push $PRIVATE_REPO/$2/$3
}

# OPERATOR
import_image docker.io istio operator:1.8.2

# PILOT
import_image docker.io istio pilot:1.8.2

# PROXY
import_image docker.io istio proxyv2:1.8.2

# COREDNS
import_image docker.io coredns coredns:1.6.2
import_image docker.io istio coredns-plugin:0.2-istio-1.1

#JAEGER
import_image docker.io jaegertracing all-in-one:1.20

#KIALI
import_image quay.io kiali kiali-operator:v1.32.0
import_image quay.io kiali kiali:v1.32.0

#PROMETHEUS
import_image quay.io prometheus-operator prometheus-config-reloader:v0.45.0
import_image quay.io prometheus-operator prometheus-operator:v0.45.0
import_image quay.io prometheus prometheus:v2.24.0
import_image quay.io prometheus alertmanager:v0.21.0
import_image quay.io prometheus node-exporter:v1.0.1
import_image quay.io coreos kube-state-metrics:v1.9.7
import_image docker.io jettech kube-webhook-certgen:v1.5.0

#GRAFANA
import_image docker.io kiwigrid k8s-sidecar:1.1.0
import_image docker.io grafana grafana:7.3.5
import_image docker.io bats bats:v1.1.0
import_image docker.io curlimages curl:7.73.0
import_image quay.io kiwigrid k8s-sidecar:1.10.7
import_image docker.io grafana grafana-image-renderer:latest

docker pull docker.io/busybox:1.31.1
docker tag docker.io/busybox:1.31.1 $PRIVATE_REPO/busybox:1.31.1
docker push $PRIVATE_REPO/busybox:1.31.1