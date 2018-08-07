# Kubernetes Operators

## Kubernetes Custom Resource Definition

- **A Resource** - is an endpoint that stores a collection of API objects of a
certain kind For example, the built-in pods resource contains a collection of Pod objects.

- **A Custom Resource** - is an object that extends the Kubernetes API.
It allows you to introduce your own API into a project or a cluster.

- **A Custom Resource Definitions (CRD)** - is a file that describes your own object
kinds and lets the Kubernetes API server handle the entire lifecycle. Deploying
a CRD into the cluster causes the Kubernetes API server to begin serving the specified custom resource.

Example:
```yaml
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  # name must match the spec fields below, and be in the form: <plural>.<group>
  name: crontabs.stable.example.com
spec:
  # group name to use for REST API: /apis/<group>/<version>
  group: stable.example.com
  # list of versions supported by this CustomResourceDefinition
  versions:
    - name: v1
      # Each version can be enabled/disabled by Served flag.
      served: true
      # One and only one version must be marked as the storage version.
      storage: true
  # either Namespaced or Cluster
  scope: Namespaced
  names:
    # plural name to be used in the URL: /apis/<group>/<version>/<plural>
    plural: crontabs
    # singular name to be used as an alias on the CLI and for display
    singular: crontab
    # kind is normally the CamelCased singular type. Your resource manifests use this.
    kind: CronTab
    # shortNames allow shorter string to match your resource on the CLI
    shortNames:
    - ct
```

## Exercise 1 - Prepare minikube environment

## Exercise 2 - Deploy ETCD cluster using ETCD-Operator

### Setup ETCD Operator 

Clone etcd-operator repository:
```bash
git clone git@github.com:coreos/etcd-operator.git
```

Install RBAC rules (cluster Roles and RoleBindings):
```bash 
etcd-operator/example/rbac/create_role.sh

# Verify that RBAC objects are present:
kubectl get clusterrole etcd-operator

kubectl get clusterrolebinding etcd-operator
```

Install ETCD Operator itself:
```bash
kubectl create -f etcd-operator/example/deployment.yaml

# Verify that etcd-operator deployment is running
kubectl get deployment etcd-operator

# Verify that etcd-operator created CRD 
kubectl get crd
```

### Install ETCD Cluster using ETCD Operator

```bash
echo | kubectl create -f - <<EOF
apiVersion: "etcd.database.coreos.com/v1beta2"
kind: "EtcdCluster"
metadata:
  name: "example-etcd-cluster"
spec:
  size: 3
  version: "3.2.13"
EOF
```

Verify the state of deployed ETCD cluster
```bash
kubectl describe etcdcluster example-etcd-cluster
```

#### Cluster wide operators ####

The above example created `etcd-operator` in `default` namespace and ETCD Cluster in same namespace. 
By default ETCD Operator reacts only on `etcdcluster` objects that are in same namespace. This behavior can be changed by passing arg `-cluster-wide` to `etcd-operator` and creating `etcdcluster` object with annotation: `etcd.database.coreos.com/scope: clusterwide`. From our example: 

```yaml
apiVersion: "etcd.database.coreos.com/v1beta2"
kind: "EtcdCluster"
metadata:
  name: "example-etcd-cluster"
  annotations:
    etcd.database.coreos.com/scope: clusterwide
spec:
  size: 3
  version: "3.2.13"
```

Note: You need to update RBAC rules if you want ETCD Operator to manage resources across all kubernetes cluster. 

### Cleanup ETCD Operator from k8s cluster

```bash
kubectl delete etcdcluster example-etcd-cluster
kubectl delete -f example/deployment.yaml
kubectl delete endpoints etcd-operator
kubectl delete crd etcdclusters.etcd.database.coreos.com
kubectl delete clusterrole etcd-operator
kubectl delete clusterrolebinding etcd-operator
```

## Operators Framework

- Introduce/describe
- Walk through components
  - Lifecycle manager
  - Operator-SDK

## Exercise 3 - Write simple Operator in Python
