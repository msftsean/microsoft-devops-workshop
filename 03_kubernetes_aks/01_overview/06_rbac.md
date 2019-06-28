# Role Based Access Control (RBAC)

Role-based access control (RBAC) is a method of regulating access to computer or network resources based on the roles of individual users within an enterprise.

`RBAC` uses the `rbac.authorization.k8s.io` API group to drive authorization decisions, allowing admins to dynamically configure policies through the Kubernetes API.


NOTE: Kubernetes has additional primitives which are specific to RBAC, and have been GA since version 1.8.

See: [RBAC Official Docs](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

#### Role

A Role can only be used to grant access to resources within a single namespace.

```
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```

#### ClusterRole

A ClusterRole can be used to grant the same permissions as a Role, but they are cluster-scoped can grant access to:
- cluster-scoped resources (like nodes)
- non-resource endpoints (like "`/healthz`")
- namespaced resources (like Pods) across all namespaces (needed to run `kubectl get pods --all-namespaces`, for example)

```
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  # "namespace" omitted since ClusterRoles are not namespaced
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]
```

#### RoleBinding

A RoleBinding may reference a Role in the same namespace. The following RoleBinding grants the "pod-reader" role to the user "jane" within the "default" namespace. This allows "jane" to read Pods in the "default" namespace.

```
# This role binding allows "jane" to read Pods in the "default" namespace.
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: User
  name: jane # Name is case sensitive
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role # this must be Role or ClusterRole
  name: pod-reader # this must match the name of the Role or ClusterRole you wish to bind to
  apiGroup: rbac.authorization.k8s.io
```

A RoleBinding may also reference a ClusterRole to grant the permissions to namespaced resources defined in the ClusterRole within the RoleBinding's namespace.

```
# This role binding allows "dave" to read secrets in the "development" namespace.
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-secrets
  namespace: development # This only grants permissions within the "development" namespace.
subjects:
- kind: User
  name: dave # Name is case sensitive
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

#### ClusterRoleBinding

A ClusterRoleBinding may be used to grant permission at the cluster level and in all namespaces.

```
# This cluster role binding allows anyone in the "manager" group to read secrets in any namespace.
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-secrets-global
subjects:
- kind: Group
  name: manager # Name is case sensitive
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

#### ServiceAccount

Service accounts can replace "User" in the `subjects` section of each role binding. These are also defined as YAML, and are generally used to allow Pods to make API calls, from within the cluster. For instance, the Ingress Controller add-ons mentioned in the previous section, use serviceAccounts to fetch Pod IP addresses, and the cluster-autoscaler add-on uses the API to read and respond to "Unschedulable" events. There is also a specialized Jenkins container designed to run on Kubernetes, which utlilizes the API to spin up each worker as a Pod of containers, at the time a job is scheduled.

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
```

For example, to assign a Service Account to a Role, you might do something similar to the following:
```
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: jenkins
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["create","delete","get","list","patch","update","watch"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create","delete","get","list","patch","update","watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get","list","watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
```
```
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: jenkins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: jenkins
subjects:
- kind: ServiceAccount
  name: jenkins
```

## Privilege escalation prevention

The RBAC API prevents users from escalating privileges by editing roles or role bindings. Because this is enforced at the API level, it applies even when the RBAC authorizer is not in use.

* You cannot create a Role or ClusterRole that grants permissions you do not have.
* You cannot create a RoleBinding or ClusterRoleBinding that binds to a Role with permissions you do not have (unless you have been explicitly given "bind" permission on the role).
* Grant explicit bind access:
```
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: role-grantor
rules:
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["rolebindings"]
  verbs: ["create"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterroles"]
  verbs: ["bind"]
  resourceNames: ["admin", "edit", "view"]
```
