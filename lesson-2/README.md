# Kubernetes Scheduling

The purpose of this workshop is to help you expand your Kubernetes knowledge. In this part we will look
how to run more sophisticated deployments and will show you how you can use python to easily interact with Kubernetes API server. We will be using Gordon application form previous workshop, so be sure you have it available.

# Topics

- [StatefulSets](#statefulsets)
  - [How Can I Access My App Inside Cluster?](#how-can-i-access-my-app-inside-cluster)
- [Kubernetes API](#kubernetes-api)
  - [Preparing Python Env](#preparing-python-env)
  - [Preparing Pod](#preparing-pod)
  - [Talking to Kubernetes API](#talking-to-kubernetes-api)
  - [Scheduling a Pod](#scheduling-a-pod)
  - [Moving Your Scheduler Inside of Your Cluster](#moving-your-scheduler-inside-of-your-cluster)
- [DaemonSets](#daemonsets)

## Setup 

export kubernetes username via:

If using minikube, export use:
```bash
$ export KUBERNETES_USER=default
```

If using kubernetes cluster provided by instructor, use
```bash
$ export KUBERNETES_USER=<YOUR_CUSTOM_USERNAME>
```


## StatefulSets

StatefulSets are the way of how to run your stateful application inside of Kubernetes.
In comparison with ReplicaSet it offers you:

1) Stable network identity for your pods
2) Controlled order of scaling and termination
3) Controlled update environment (updating in predictable order)

We will start by creating our first stateful service. Change `${REGISTRY_USER}` to point to your image or use `prgcont` if you want to use our image. Define following object to Kubernetes (use ``kubectl create -f`` command for it).

```yaml
apiVersion: v1
kind: Service
metadata:
  name: gordon
  labels:
    app: gordon
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: gordon
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: webgordon
spec:
  serviceName: "gordon"
  replicas: 2
  selector:
    matchLabels:
      app: gordon
  template:
    metadata:
      labels:
        app: gordon
    spec:
      containers:
      - name: gordon
        image: ${REGISTRY_USER}/gordon:v1.0
        ports:
        - containerPort: 8080
          name: web
        volumeMounts:
        - name: www
          mountPath: /mnt/vol
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```

Then you can see what happened by executing:

```bash
$ kubectl get all
```

You should see the service and two pods `webgordon-0` and `webgordon-1`

### How Can I Access My App Inside Cluster?

To access your app we will hook inside Kubernetes network via `kubectl proxy` command, so please open a new terminal and run

```bash
$  kubectl proxy
```

! IMPORTANT - Do not stop proxy as following commands will not work.

Now you can try to access your application via service.

```bash 
$ curl http://localhost:8001/api/v1/namespaces/${KUBERNETES_USER}/services/gordon/proxy/
```

**and this will fail**. We can now try to access our pods via:

```bash 
$ curl http://localhost:8001/api/v1/namespaces/${KUBERNETES_USER}/pods/webgordon-1/proxy/
```

So how can I access my app? If you are running stateful application you probably don't want to have any automatic load balancing and you can use predictable DNS record for any pod. We can try it by executing shell inside of our container and curling another one:

```bash
$ kubectl exec -ti  webgordon-1 bash
# curl webgordon-0.gordon:8080
```

As you can see you can access your pods by `webgordon-$id.gorgon` name inside of your cluster.

If you examine the service object you will find out, that we've created a [headless service](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services).

### Tasks

* Scale your application to 4 pods
* Examine all resources, (pods, pvc, services) that were created.
* Find a `template` in resource definition to see how it works
* Try to access all of the stateful pods in the cluster
* Scale your application back to 2 pods
* Examine all resources again

### Advanced tasks

* Suggest a way of how to access your stateful application via ingress controller
* Implement previous tasks

## Kubernetes API

In this chapter we will start to talk with Kubernetes API.
We will do it by writing a very simple pod scheduler.
Language of our choice is Python, but you can use almost any other language - the principles will the same.

### Preparing Python Env

We will start by creating Python virtual environment

```bash
$ virtualenv ~/kube
$ source ~/kube/bin/activate
$ pip install kubernetes
```

### Preparing pod

We will now create a pod which will tell Kubernetes to wait for our custom
scheduler. You can do it by feeding Kubernetes with following YAML:

```yaml
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hello
spec:
  schedulerName: PrgContSched
  containers:
  - name: hello
    image: ${REGISTRY_USER}/gordon:v1.0
EOF
```

Now if we will run `kubectl get pods` we'll see our pod stuck in a `Pending` state. This is the
initial state of a pod and Kubernetes default scheduler is ignoring this pod as we marked our pod to be schedulable via `PrgContSched` scheduler.

### Talking to Kubernetes API

First we will create a simple Python script which will connect to Kubernetes and will list all Pods waiting to be scheduled:

```python
from kubernetes import client, config, watch

# Following line is sourcing your ~/.kube/config so you are authenticated same way
# as kubectl is
config.load_kube_config()
v1 = client.CoreV1Api()
namespace = config.list_kube_config_contexts()[1]["context"]["namespace"]

def main():
    w = watch.Watch()
    for event in w.stream(v1.list_namespaced_pod, namespace):
        print("pod: '%s', phase: '%s'." % (event['object'].metadata.name,
                                           event['object'].status.phase))
                   
if __name__ == '__main__':
    main()
```

You should see your pod in the `Pending` state.

### Tasks

* Look at [Kubernetes Python API docs](https://github.com/kubernetes-client/python/blob/master/kubernetes/docs/V1Pod.md) and adjust python script to print name of the requested scheduler too.

### Scheduling a Pod

To be able to schedule our pod we will create a simple Schedule function:

```python
def scheduler(name, node, namespace=namespace):
        
    target=client.V1ObjectReference()
    target.kind = "Node"
    target.apiVersion = "v1"
    target.name = node
    
    meta = client.V1ObjectMeta()
    meta.name = name
    
    body = client.V1Binding(metadata=meta, target=target)
    
    return v1.create_namespaced_binding(namespace, body)
```

and adjust our main function to look like:

```python
def main():
    w = watch.Watch()
    for event in w.stream(v1.list_namespaced_pod, namespace):
        print("pod: '%s', phase: '%s' %s." % (event['object'].metadata.name,
                                           event['object'].status.phase,
                                           event['object'].spec.scheduler_name))
        if event['object'].status.phase == "Pending" and event['object'].spec.scheduler_name == "PrgContSched":
            try:
                res = scheduler(event['object'].metadata.name, 'minikube')
            except Exception as ex:
                print(ex)
```

When you run your function it should schedule a pod. If you get an exception you can probably ignore it as there is currently bug in this [API](https://github.com/kubernetes-client/gen/issues/52).

Check pod state by invoking:

```bash
$ kubectl get pods
```

### Moving Your Scheduler Inside of Your Cluster

To move your scheduler to be run inside your Kubernetes cluster you need to change only one line `config.load_kube_config()` to `config.load_incluster_config()` so your scheduler will look like:

```python
from kubernetes import client, config, watch

# Following line is sourcing your ~/.kube/config so you are authenticated same way
# as kubectl is
config.load_kube_config()
namespace = config.list_kube_config_contexts()[1]["context"]["namespace"]
print("Namespace from kubeconfig: {}".format(namespace))

v1 = client.CoreV1Api()


def scheduler(name, node):

    target=client.V1ObjectReference()
    target.kind = "Node"
    target.apiVersion = "v1"
    target.name = node

    meta = client.V1ObjectMeta()
    meta.name = name

    body = client.V1Binding(metadata=meta, target=target)

    return v1.create_namespaced_binding(namespace, body)

def main():
    w = watch.Watch()
    for event in w.stream(v1.list_namespaced_pod, namespace):
        print("pod: '%s', phase: '%s' %s." % (event['object'].metadata.name,
                                           event['object'].status.phase,
                                           event['object'].spec.scheduler_name))
        if event['object'].status.phase == "Pending" and event['object'].spec.scheduler_name == "PrgContSched":
            try:
                res = scheduler(event['object'].metadata.name, 'worker-01')
            except Exception as ex:
                print(ex)


if __name__ == '__main__':
    main()
```

### Tasks

* Build this scheduler as a Docker image
* Deploy it to the Kubernetes
* Schedule a pod with it

## DaemonSets

[DaemonSets](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset) are a special objects
in Kubernetes clusters which enables you to run 1 instance of your application on every node of your Cluster.

This is very useful for deploying infrastructure like types of applications (for example. Prometheus or CEPH/Gluster clusters).

To create a DaemonSet please feed following object to a Kubernetes cluster. Don't forget to change `${REGISTRY_USER}` variable!

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: gordon
spec:
  selector:
    matchLabels:
      name: gordon
  template:
    metadata:
      labels:
        name: gordon
    spec:
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: gordon
        image: ${REGISTRY_USER}/gordon:v1.0
      terminationGracePeriodSeconds: 30
```

### Tasks

* Look at possible [alternatives](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/#alternatives-to-daemonset) to DaemonSets.
* Suggest how to communicate with DaemonSets pods as load balancing is probably not good idea here. Explain why.
