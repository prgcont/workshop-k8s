# Prometheus - Kubernetes monitored

## Table of Contents
- [Prerequisites](#Prerequisites)
- [Run Prometheus in Kubernetes](#run-prometheus-in-kubernetes)
  - [Prepare the Namespace](#prepare-the-namespace)
  - [Deploying Prometheus](deploying-prometheus)
    - [ConfigMap](#configmap)
    - [Prometheus](#prometheus)
    - [Prometheus Service](#prometheus-service)
- [Run Grafana]()
- [Prometheus Node Exporter]()

## Prerequisites
- `git clone https://github.com/prgcont/workshop-k8s && cd workshop-k8s/src/prometheus`
- [Install Hypervisor](https://github.com/prgcont/workshop-k8s/tree/master/lesson-1#install-hypervisor)
- [Install Minikube](https://github.com/prgcont/workshop-k8s/tree/master/lesson-1#install-minikube)
- [Install Kubeectl](https://github.com/prgcont/workshop-k8s/tree/master/lesson-1#install-minikube)
- [Test Your Setup](https://github.com/prgcont/workshop-k8s/tree/master/lesson-1#run-minikube)

## Run Prometheus in Kubernetes

### Prepare the Namespace
We're going to follow the best practices and run everything monitoring-related in a special namespaces, the namespaces will be named `monitoring`. To create the new namespace in Kubernetes run:

```bash
kubectl create namespace monitoring
```

Now list all the namespaces via:
```
kubectl get namespaces
NAME          STATUS    AGE
default       Active    4m
kube-public   Active    4m
kube-system   Active    4m
monitoring    Active    5s
```
As you can see, `monitoring` namespace was created successfully.

### Deploying Prometheus

NOTE: All `kubectl apply` commands should be run from the cloned workshop-k8s
repository (see [Prerequisites]([Prerequisites](#Prerequisites)).

#### ConfigMap
Prometheus will get its configuration from a [Kubernetes ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/).
This allows us to update the configuration separate from the image.
This is just a [Prometheus configuration](https://github.com/prometheus/prometheus/blob/master/documentation/examples/prometheus-kubernetes.yml)
transformed to the Kubernetes manifest.

To deploy this to Kubernetes run
```bash
kubectl apply -f prometheus-config.yaml
```

Make sure that the ConfigMap was created successfully:
```bash
kubectl get configmap prometheus-config -n monitoring
NAME                DATA      AGE
prometheus-config   1         25s
```

#### Prometheus

[Here](https://github.com/prgcont/workshop-k8s/blob/master/src/prometheus/prometheus-deployment.yaml)
is the Prometheus deployment that we're going to use during our workshop

In the *metadata section*, we give the pod a label with a key of name and a value of prometheus.
This will come in handy later.

In *annotations*, we set a couple of key/value pairs that will actually allow Prometheus
to autodiscover and scrape itself.

We are using an [*emptyDir*](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir)
volume for the Prometheus data. It exists as long as Prometheus Pod is running on that node.
As the name says, it is initially empty.
Containers in the Prometheus Pod can all read and write the same files in the emptyDir volume,
though that volume can be mounted at the same or different paths in each Container.
When a Pod is removed from a node for any reason, the data in the *emptyDir* is deleted forever.

To install Prometheus run the following command:

```bash
kubectl apply -f prometheus-deployment.yaml
```

Make sure that prometheus is up and running:
```bash
kubectl get deployments -n monitoring
NAME         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
prometheus   1         1         1            1           52s
```

#### Prometheus Service
In order to get to the UI of Prometheus we have to expose it via [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/). In our
workshop we will use [NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#nodeport)

To add NodePort service to your kubernetes cluster run
```bash
kubectl apply -f prometheus-service.yaml
```
List all your services in `monitoring` namespace:
```bash
kubectl get svc -n monitoring
NAME         TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
prometheus   NodePort   10.102.142.14   <none>        9090:30090/TCP   9s
```

Now you can open prometheus UI via:
```
minikube service prometheus -n monitoring
```

Click `Status -> Targets`and you should see the Kubernetes cluster and nodes. You should also see that Prometheus discovered itself under kubernetes-pods.
