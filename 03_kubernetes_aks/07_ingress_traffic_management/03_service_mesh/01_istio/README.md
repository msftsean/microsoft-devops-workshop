# Istio

Istio is the most feature-rich open-source service mesh solution. 

The control plane of istio consists of the following components:

- IstioD 
	- Pilot - Service Discovery / DNS
	- Citadel - Certificate Generation
	- Galley - Configuration Management
	- Sidecar Injector
- Ingress Gateway
- Egress Gateway (Optional)

and optionally, some Add-On Components which may be required for certain capabilities:

- Cert-Manager
- Grafana
- Prometheus
- Tracing / Jaeger / Zipkin
- Kiali

![Istio Architecture](https://istio.io/latest/docs/ops/deployment/architecture/arch.svg)

## Changelog / Updates

Istio is a rapidly evolving piece of software, as such, its imperative that the end-user keeps up to date with the latest changes and upgrade paths.

https://istio.io/latest/news/releases/

Notable changes in the recent past, that had major impacts:

- Prior to version 1.5, the individual components were deployed as separate micro-services, now they are a single istiod binary.
- Prior to version 1.8, the addons could be installed directly with the Istio Operator.
- In version 1.8 the Mixer component was removed and deprecated.

## Table of Contents

1. [Install Istio](01_install_istio.md)
