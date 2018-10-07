# Kubernetes 101

The purpose of this workshop series is to get you on boarded to Kuberentes experience. We will guide you through deploying first applications,
scaling them and accessing them from outside network via Ingress routing. We will also briefly touch data persistence which will help you to run
simple stateful applications.

Topics:

- [Setup minikube](#setup-minikube)
  - [Install Hypervisor](#install-hypervisor)
  - [Install Kubectl](#install-kubectl)
  - [Install Minikube](#install-minikube)
  - [Run Minikube](#run-minikube)
  - [External Kubernetes Cluster](#external-kubernetes-cluster)
- [Prepare Demo Application](#prepare-demo-application)
- [Deploy Your First Application](#deploy-your-first-application)
  - [What Just Happened?](#what-just-happened)
- [How Can I Access My App?](#how-can-i-access-my-app)
- [Service](#service)
- [Pod](#pod)
- [Scaling Your Application](#scaling-your-application)
- [Persistent storage](#persistent-storage)
  - [Claiming Persistent Volumes](#claiming-persistent-volumes)
  - [Injecting PVC into Your Application](#injecting-pvc-into-your-application)
- [Ingress Controller](#ingress-controller)
  - [Ingress Controller is Needed](#ingress-controller-is-needed)
  - [Why Nginx?](#why-nginx)
  - [Defaultbackend](#defaultbackend)
  - [Nginx-Ingress & Defaultbackend](#nginx-ingress-and-defaultbackend)
  - [Simple Application](#simple-application)
  - [RC and Service](#rc-and-service)
  - [Multiple Services](#multiple-services)
  - [Configuring Ingress to Handle HTTPS traffic](#configuring-ingress-to-handle-https-traffic)
  - [Bonus 1 - Mapping the Different Services to the Different Hosts](#bonus-1---mapping-the-different-services-to-the-different-hosts)
  - [Bonus 2 - Step-by-step guide to Enable Nginx Ingress Addon in Minikube](#bonus-2---step-by-step-guide-to-enable-nginx-ingress-addon-in-minikube)

## Setup Minikube

! IMPORTANT ! VT-x or AMD-v virtualization must be enabled in your computer’s BIOS.

### Install Hypervisor

If you do not already have a hypervisor installed, install one now:

- For OS X, install `VirtualBox` or `VMware Fusion`, or `HyperKit`.
- For Linux, install `VirtualBox` or `KVM`.
- For Windows, install `VirtualBox` or `Hyper-V`.

Note: Minikube also supports a `--vm-driver=none` option that runs the Kubernetes components on the host and not in a VM. Docker is required to use this driver but a hypervisor is not required.

### Install Kubectl

Install kubectl according to [these instructions](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

### Install Minikube

Install Minikube according to the instructions for the [release 0.28.0](https://github.com/kubernetes/minikube/releases/tag/v0.28.0)

### Run Minikube

If you want to change the VM driver add the appropriate `--vm-driver=xxx` flag to `minikube start`.

```bash
$ minikube start
Starting local Kubernetes cluster...
Running pre-create checks...
Creating machine...
Starting local Kubernetes cluster...
```

And the last thing, export kubernetes username via:

```bash
$ export KUBERNETES_USER=default
```

### External Kubernetes Cluster

Instead of Minikube, you can use specially created Kubernetes cluster provided by instructor.
Kubeconfigs will be destributed in the beginning of the workshop.
Don't forget to point your `KUBECONFIG` environment variable to this Kubeconfig. 

```bash
$ export KUBECONFIG=<path_to_kubeconfig>
```

and to export your kubernetes username via:

```bash
$ export KUBERNETES_USER=<user_from_kubeconfig>
```

## Prepare Demo Application

We're going to use a simple NodeJS application. The image is already pushed to DockerHub (`prgcont/gordon:v1.0`) but you should never-ever download and run unknown images from DockerHub, so let's build it instead.

Here is the app:

```javascript
const http = require('http');
const os = require('os');

console.log("Gordon server starting...");

var handler = function(request, response) {
  console.log("Received request from " + request.connection.remoteAddress);
  response.writeHead(200);
  response.end("You've hit gordon v1, my name is " + os.hostname() + "\n");
};

var www = http.createServer(handler);
www.listen(8080);
```

If you're not familiar with NodeJS, this app basically answers with greetings and hostname to any request to port `8080`.

Save it as `app-v1.js` and let's create a Dockerfile for it:

```dockerfile
FROM node:10.5-slim
ADD app-v1.js /app-v1.js
EXPOSE 8080
ENTRYPOINT ["node", "app-v1.js"]
```

now build it:

```bash
$ export REGISTRY_USER=<your_name>
$ docker build -t ${REGISTRY_USER}/gordon:v1.0 .
```

And push it either to DockerHub or to your favorite Docker registry.

! IMPORTANT - All source code is [here](https://github.com/prgcont/workshop-k8s/tree/master/src/ingress)

## Deploy Your First Application

Now we can deploy our application into minikube:

```bash
$ kubectl run hello --image=${REGISTRY_USER}/gordon:v1.0 --port=8080 --expose
```

### What Just Happened?

We asked Kubernetes to deploy our application and to expose port 8080 for it.

## How Can I Access My App?

To access your app we will hook inside Kubernetes network via `kubectl proxy` command, so please open a new terminal and run

```bash
$ kubectl proxy
Starting to serve on 127.0.0.1:8001
```

! IMPORTANT - Do not stop proxy as the following commands will not work !

you can access your application via following command

```bash
$ curl http://localhost:8001/api/v1/namespaces/$KUBERNETES_USER/services/hello/proxy/
You've hit gordon v1, my name is hello-d878f6778-lxb5c
```

## Service

Did you notice a word `service` inside the URL? Yes, we are using kubernetes service to access our application. You can see how the service object looks by running:

```bash
$ kubectl describe service hello
```

Or you can list all other services via:

```bash
$ kubectl get services
```

Why Service is there? The Service is a very important object in Kubernetes. It's an abstraction for your deployed applications. It helps you to discover your pods, to load balance them and
many other scenarios. You can learn more in upstream [doc](https://kubernetes.io/docs/concepts/services-networking/service/). You can imagine it in the following way:

```bash

    +-------+
    |service|
    +-------+
        |
  +-----|-----+
  |     |     |
+---+ +---+ +---+
|pod| |pod| |pod|
+---+ +---+ +---+
```

## Pod

As you already know, a group of containers running in a Kubernetes cluster is called `Pod`. So let's look which pods are running in our Kubernetes cluster by executing:

```bash
$ kubectl get pods
```

You can see how the Pod is defined by executing (replace `<pod_name>` by Pod name from the previous output):

```bash
$ kubectl describe pod <pod_name>
```

you can even access Pod directly via `curl` by:

```bash
$ export POD_NAME=$(kubectl get pods | grep hello | cut -f 1 -d ' ' | head -n 1)
$ curl -L http://localhost:8001/api/v1/namespaces/$KUBERNETES_USER/pods/$POD_NAME/proxy/
You've hit gordon v1, my name is <pod_name>
```

## Scaling Your Application

As we deployed our application via `kubectl run` command, it was created using `deployment` object (learn more about Deployments in Kubernetes [here](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)), we can view it via:

```bash
$  kubectl describe deployment hello
```

By examining the whole output of the previous command, you can see a Pod template with our container image, and the most important part for us is the line with the word `Replicas`. This tells
Kubernetes how many instances of our application we want to have. We can scale our deployment by executing

```bash
$ kubectl scale --replicas=3 deployment/hello
```

This will ask Kubernetes to scale up the deployment of our application to 3 instances. The number of instances is guarded by `ReplicaSet`. You can list and describe ReplicaSets by following commands
(replace ... by name of your ReplicaSet):

```bash
$ kubectl get rs
$ kubectl describe rs/...
```

*note:* You can still find people using `ReplicationControllers` instead of `ReplicaSets` which is an outdated approach and you should avoid it as both object works almost the same way with `ReplicaSets` enabling you
to use more advance [labels/selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#label-selectors) mechanisms.

When we list pods again we should see 3 of them:

```bash
$ kubectl get pods
```

We can test that all of the pods are being used by `curl` the service url (remember service is providing load balancing of pods) via:

```bash
$ for i in $(seq 1 20); do curl http://localhost:8001/api/v1/namespaces/$KUBERNETES_USER/services/hello/proxy/; done
```

### Tasks

1. How can service find its targeted pods?
2. Run `minikube dashboard` and find all the objects we described using the Kubernetes Dashboard

## Persistent Storage

In this chapter, we will look at how can we add a persistent storage to our applications. This topic is very important as a lot of outstanding
application needs some storage access. We can argue, that we should not need any persistent storage and just consume API. But in the real world
you will face a need of providing file-system like storage for your pods. Persistent volumes are usually network filesystems. You can see
a list of supported providers at [upstream docs](https://kubernetes.io/docs/concepts/storage/volumes/#types-of-volumes)

### Claiming Persistent Volumes

Minikube comes with auto-provisioned persistent volumes, they are created as you ask for them. Any application which needs a persistent volume
must claim it. You can do it, by creating `PersistentVolumeClaim (PVC)` by executing the following command:

```bash
cat <<EOF | kubectl create -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: testpvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 2Gi
EOF
```

Then you can list your newly created PVC by executing:

```bash
$ kubectl get pvc
$ kubectl describe pvc testpvc
```

### Injecting PVC into Your Application

**!!!Note**: In case you are running in shared DO cluster add selector to force all pods to start on single node only, e.g.:
```
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/hostname: worker-01
```

To inject the PVC into our application we need to edit its "deployment" object by executing:

```bash 
$ kubectl edit deployment hello
```

then look for a following section:

``` yaml
...
      containers:
      - image: <your_name>/gordon:v1.0
        imagePullPolicy: IfNotPresent
        name: hello
        ports:
        - containerPort: 8080
          protocol: TCP
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
...
```

and change it to:

``` yaml
      containers:
      - image: <your_name>/gordon:v1.0
        imagePullPolicy: IfNotPresent
        name: hello
        ports:
        - containerPort: 8080
          protocol: TCP
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /srv/
          name: test
      volumes:
      - name: test
        persistentVolumeClaim:
          claimName: testpvc
      dnsPolicy: ClusterFirst
```

Now we can select one pod and execute:

```bash
$ export POD_NAME=$(kubectl get pods | grep hello | cut -f 1 -d ' ' | head -n 1)
$ kubectl exec -ti $POD_NAME touch /srv/test_file
```

Than you can check that other pods can see the data by executing the following command for each pod:

```bash
$ for i in $(kubectl get pods | grep hello | cut -f 1 -d ' '); do kubectl exec -it  $i ls /srv; done
```

you should see test_file on every pod.

### Tasks

1. Scale your application to 0 replicas and run it again and see that data still present
2. Scale your application to 0 pod and recreate pvc, will data exist?
3. Explain why there is a different outcome for previous tasks. You can look at PVC [lifecycle](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#lifecycle-of-a-volume-and-claim)

## Ingress Controller

*Ingress - the action or fact of going in or entering; the capacity or right of the entrance. Synonyms: entry, entrance, access, means of entry, admittance, admission;*

An API object that manages external access to the services in a cluster, typically HTTP.

Ingress can provide load balancing, SSL termination and name-based virtual hosting.

### Ingress Controller is Needed

This is unlike other types of controllers, which typically run as part of the kube-controller-manager binary, and which are typically started automatically as part of cluster creation.

You can choose any Ingress controller:

- haproxy
- Nginx
- ...

### Why Nginx?

- Nginx Ingress Controller officially supported by Kubernetes, as we already now.
- it’s totally free :)
- It’s the default option for minikube, which we will use to test Ingress behavior in Kubernetes.

## Defaultbackend

An Ingress with no rules sends all traffic to a single default backend. Traffic is routed to your default backend if none of the Hosts in your Ingress match the Host in the request header, and/or none of the paths match the URL of the request.

### Nginx-Ingress and Defaultbackend

In case of minikube run ``minikube addons enable ingress`` to activate defaultbackend and nginx-ingress-controller:
In case of External Kubernetes Cluster - you already have Nginx Ingress controller.

### Simple Application

Conceptually, our setup should look like this:

```bash
    internet
        |
   [ ingress ]
        |
   [ service ]
        |
      [RC]
   --|--|--|--
     [pods]
```

### RC and Service

Now let's create a ReplicationController and a Service: they will be used by Ingress

```bash
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: ReplicationController
metadata:
  name: gordon-v1
spec:
  replicas: 3
  template:
    metadata:
      name: gordon-v1
      labels:
        app: gordon-v1
    spec:
      containers:
      - image: prgcont/gordon:v1.0
        name: nodejs
        imagePullPolicy: Always
---
apiVersion: v1
kind: Service
metadata:
  name: gordon-service-v1
spec:
  selector:
    app: gordon-v1
  ports:
  - port: 80
    targetPort: 8080
EOF
```

Check that service is up and running:

```bash
$  kubectl get svc
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
gordon-service-v1   ClusterIP   10.111.33.157   <none>        80/TCP    1d
kubernetes          ClusterIP   10.96.0.1       <none>        443/TCP   6d
```

Great, now let's create our first version of ingress:

**!!!Note**: Namespace your `path` to your namespace name, e.g. `path: /<NAMESPACE>/v1` in case you use shared exercise cluster.

```bash
cat <<EOF | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: gordon
spec:
  rules:
  # this ingress maps the gordon.example.lan domain name to our service
  # you have to add gordon.example.lan to /etc/hosts
  - host: gordon.example.lan
    http:
      paths:
      # all requests will be sent to port 80 of the gordon service
      - path: /v1
        backend:
          serviceName: gordon-service-v1
          servicePort: 80
EOF
```

To be able to access the ingress from the outside we’ll need to make sure the hostname resolves to the IP of the ingress controller.
We can do it via:

- adding the hostname gordon.example.lan into /etc/hosts (don't forget to delete it afterwards!)
- changing the hostname `gordon.example.lan` to `gordon.example.lan.<CLUSTER_IP>.nip.io` in the previous YAML file - it will use [nip.io](http://nip.io/) service for resolving the hostname
  - where `CLUSTER_IP` is either your minikube ip or LB IP provided by instructors.
- in case of production applications we will need to set up DNS resolving properly.

Check that ingress is available:

```bash
$ kubectl get ing
NAME      HOSTS                ADDRESS        PORTS     AGE
gordon    gordon.example.lan   <some_ip_address_here>   80        1h
```

Let's test our ingress:

if you use Minikube run

```bash
$ for i in {1..10}; do curl http://gordon.example.lan/v1; done
You've hit gordon v1, my name is gordon-v1-z99d6
You've hit gordon v1, my name is gordon-v1-btkvr
You've hit gordon v1, my name is gordon-v1-64hhw
You've hit gordon v1, my name is gordon-v1-z99d6
You've hit gordon v1, my name is gordon-v1-btkvr
You've hit gordon v1, my name is gordon-v1-64hhw
You've hit gordon v1, my name is gordon-v1-z99d6
You've hit gordon v1, my name is gordon-v1-btkvr
You've hit gordon v1, my name is gordon-v1-64hhw
You've hit gordon v1, my name is gordon-v1-z99d6
```

! IMPORTANT In case of the External Kubernetes Cluster you will need to specify the port, for example:

```bash
for i in {1..10}; do curl http://gordon.example.lan:32132/v1; done
You've hit gordon v1, my name is gordon-v1-52nkj
You've hit gordon v1, my name is gordon-v1-2hq2b
You've hit gordon v1, my name is gordon-v1-68pvg
You've hit gordon v1, my name is gordon-v1-52nkj
You've hit gordon v1, my name is gordon-v1-2hq2b
You've hit gordon v1, my name is gordon-v1-68pvg
You've hit gordon v1, my name is gordon-v1-52nkj
You've hit gordon v1, my name is gordon-v1-2hq2b
You've hit gordon v1, my name is gordon-v1-68pvg
```

If you will try to request http://gordon.example.lan it will give you a default backend's 404:

```bash
$ curl http://gordon.example.lan
default backend - 404
```

This is because we have a rule only for /v1 path in our ingress YAML. An Ingress with no rules sends all traffic to a single default backend. Traffic is routed to your default backend if none of the Hosts in your Ingress match the Host in the request header, and/or none of the paths match the URL of the request.

The biggest advantage of using ingresses is their ability to expose multiple services through a single IP address, so let’s see how to do that.

### Multiple Services

Let's create a second app, it's, basically, the same application with the slightly different output:

```javascript
const http = require('http');
const os = require('os');

console.log("Gordon Server is starting...");

var handler = function(request, response) {
  console.log("Received request from " + request.connection.remoteAddress);
  response.writeHead(200);
  response.end("Hey, I'm the next version of gordon; my name is " + os.hostname() + "\n");
};

var www = http.createServer(handler);
www.listen(8080);
```

Save it as `app-v2.js` and let's build from the following Dockerfile:

```dockerfile
FROM node:10.5-slim
ADD app-v2.js /app-v2.js
ENTRYPOINT ["node", "app-v2.js"]
```

Build it:

```bash
$ docker build -t <your_name>/gordon:v2.0 .
```

And push it to DockerHub (don't forget to tag it accordingly).

Let's create a second ReplicationController and a Service:

```bash
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: ReplicationController
metadata:
  name: gordon-v2
spec:
  replicas: 3
  template:
    metadata:
      name: gordon-v2
      labels:
        app: gordon-v2
    spec:
      containers:
      - image: prgcont/gordon:v2.0
        name: nodejs
        imagePullPolicy: Always
---
apiVersion: v1
kind: Service
metadata:
  name: gordon-service-v2
spec:
  selector:
    app: gordon-v2
  ports:
  - port: 90
    targetPort: 8080
EOF
```

Let's check our services:

```bash
$ kubectl get svc
NAME                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
default-http-backend   ClusterIP   10.98.23.177     <none>        80/TCP    1h
gordon-service-v1      ClusterIP   10.108.177.42    <none>        80/TCP    1h
gordon-service-v2      ClusterIP   10.105.110.160   <none>        90/TCP    1h
kubernetes             ClusterIP   10.96.0.1        <none>        443/TCP   4d
```

And here is our new ingress YAML file (don't forget to remove the old one: `kubectl delete ingress gordon`):

```bash
cat <<EOF | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: gordon
spec:
  rules:
  # this ingress maps the gordon.example.lan domain name to our service
  # you have to add gordon.example.lan to /etc/hosts
  - host: gordon.example.lan
    http:
      paths:
      - path: /v1
        backend:
          serviceName: gordon-service-v1
          servicePort: 80
      - path: /v2
        backend:
          serviceName: gordon-service-v2
          servicePort: 90
EOF
```

*Don't forget to change the line `  - host: gordon.example.lan` in case you're using nip.io service for resolving*

Let's test it (don't forget to specify the port in case of External Kubernetes Cluster):

```bash
$ for i in {1..5}; do curl http://gordon.example.lan/v1; done
You've hit gordon v1, my name is gordon-v1-btkvr
You've hit gordon v1, my name is gordon-v1-64hhw
You've hit gordon v1, my name is gordon-v1-z99d6
You've hit gordon v1, my name is gordon-v1-btkvr
You've hit gordon v1, my name is gordon-v1-64hhw

$ for i in {1..5}; do curl http://gordon.example.lan/v2; done
Hey, I'm the next version of gordon; my name is gordon-v2-g6pll
Hey, I'm the next version of gordon; my name is gordon-v2-c78bh
Hey, I'm the next version of gordon; my name is gordon-v2-jn25s
Hey, I'm the next version of gordon; my name is gordon-v2-g6pll
Hey, I'm the next version of gordon; my name is gordon-v2-c78bh
```

It works!

### Configuring Ingress to Handle HTTPS Traffic

Currently, the Ingress can handle incoming HTTPS connections, but it terminates the TLS connection and sends requests to the services unencrypted.
Since the Ingress terminates the TLS connection, it needs a TLS certificate and private key to do that.
The two need to be stored in a Kubernetes resource called a `Secret`.

Create a certificate, a key and save them into Kubernetes Secret:

```bash
$ openssl genrsa -out tls.key 2048
$ openssl req -new -x509 -key tls.key -out tls.cert -days 360 -subj '/CN=gordon.example.lan'
$ kubectl create secret tls tls-secret --cert=tls.cert --key=tls.key
secret "tls-secret" created
```

Here is the "TLS" version of our ingress (again, don't forget to remove the old one: `kubectl delete ingress gordon`):

```bash
cat <<EOF | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: gordon
spec:
  tls:
  - hosts:
    - gordon.example.lan
    secretName: tls-secret
  rules:
  # this ingress maps the gordon.example.lan domain name to our service
  # you have to add gordon.example.lan to /etc/hosts
  - host: gordon.example.lan
    http:
      paths:
      - path: /v1
        backend:
          serviceName: gordon-service-v1
          servicePort: 80
      - path: /v2
        backend:
          serviceName: gordon-service-v2
          servicePort: 90
EOF
```

*Don't forget to change the line `  - host: gordon.example.lan` in case you're using nip.io service for resolving*

Let's test it (don't forget to specify the port in case of External Kubernetes Cluster):

```bash
$ curl http://gordon.example.lan/v1
<html>
<head><title>308 Permanent Redirect</title></head>
<body bgcolor="white">
<center><h1>308 Permanent Redirect</h1></center>
<hr><center>nginx</center>
</body>
</html>


$ curl -k https://gordon.example.lan/v1
You've hit gordon v1, my name is gordon-v1-64hhw
```

### Bonus 1 - Mapping the Different Services to the Different Hosts

Requests received by the controller will be forwarded to either service `foo` or `bar`, depending on the Host header in the request (exactly like how virtual hosts are handled in the web servers).
Of course, DNS needs to point both the `foo.example.lan` and the `bar.example.lan` domain names to the Ingress controller’s IP address.

Example:

```yaml
...
spec:
  rules:
  - host: foo.example.lan
    http:
      paths:
      - path: /
        backend:
          serviceName: foo
          servicePort: 80
  - host: bar.example.lan
    http:
      paths:
      - path: /
        backend:
          serviceName: bar
          servicePort: 80
...
```

### Bonus 2 - Step-by-step guide to Enable Nginx Ingress Addon in Minikube

```bash
$ minikube status
minikube: Running
cluster: Running
kubectl: Correctly Configured: pointing to minikube-vm at 192.168.64.8
```

```bash
$ minikube addons list
- addon-manager: enabled
- coredns: disabled
- dashboard: enabled
- default-storageclass: enabled
- efk: disabled
- freshpod: disabled
- heapster: disabled
- ingress: disabled
- kube-dns: enabled
- metrics-server: disabled
- registry: disabled
- registry-creds: disabled
- storage-provisioner: enabled
```

As you can see, **ingress** add-on is disabled, let’s enable it:

```bash
$ minikube addons enable ingress
ingress was successfully enabled
```

Wait for a minute and then check that your cluster runs both nginx and default-http-backend:

nginx:

```bash
$ kubectl get all --all-namespaces | grep nginx
kube-system   deploy/nginx-ingress-controller   1         1         1            1           1h
kube-system   rs/nginx-ingress-controller-67956bf89d   1         1         1         1h
kube-system   po/nginx-ingress-controller-67956bf89d-dbbl4   1/1       Running   2          1h
```

default-backend:

```bash
$ kubectl get all --all-namespaces | grep default-http-backend
kube-system   deploy/default-http-backend       1         1         1            1           1h
kube-system   rs/default-http-backend-59868b7dd6       1         1         1         1h
kube-system   po/default-http-backend-59868b7dd6-6sh5f       1/1       Running   1          1h
kube-system   svc/default-http-backend   NodePort    10.104.42.209   <none>        80:30001/TCP    1h
```
