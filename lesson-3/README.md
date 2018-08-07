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

## Operators Framework

- Introduce/describe
- Walk through components
  - Lifecycle manager
  - Operator-SDK

## Exercise 3 - Write simple Operator in Python
