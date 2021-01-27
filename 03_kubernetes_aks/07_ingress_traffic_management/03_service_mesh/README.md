# Service Mesh

Implementing a service mesh is meant to decouple traffic management from the application more thoroughly than is provided by native Kubernetes components. 

With service meshes you can generally expect to be able to enable / control:

1. Encryption of all Traffic in a Cluster
2. Canary and/or Phased Rollouts
3. Rate Limiting / Request Transformation
4. Additional Observability

Various service meshes support different sets of capabilities, and have varying degrees of overhead. 

Generally, the mesh is split into two "planes". The *Control* plane and the *Data* plane. The *Control Plane* will have a number of components that are designed to configure and manage the mesh itself; this may include one or more user interfaces for interaction/observability. The *Data Plane* generally consists of the proxy, in most cases the *Envoy* proxy, which is automatically injected into deployed pods as an additional "sidecar" container. This proxy controls all network traffic in and out of its respective pod, and gets its configuration from the control plane, which may have it encrypt/decrypt, rate limit, and/or transform requests, without the application even being aware. 

In Azure, the top 3 mesh solutions are: Istio, LinkerD, and Consul

Before deciding to implement a service mesh, it is important to consider the following:

- Is your use case something that can be handled with native kubernetes components or a simple Ingress controller?
- Does the added capability of the service mesh justify the overhead of the control/data planes in terms of cpu/mem as well as management effort?

## Table of Contents

1. [Istio](01_istio)
      1. [Install Istio](01_istio/01_install_istio.md)
