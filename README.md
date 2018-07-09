# Kubernetes 101

The purpose of this workshop series is to get you on boarded to Kuberentes experience. We will guide you through deploying first applications,
scaling them and accessing them from outside network via Ingress routing. We will also briefly touch data persistence which will help you to run 
simple statefull applications.


Topics:
- [Setup minikube](#setup-minikube)
  - [Install Hypervisor](#install-hypervisor)
  - [Install Kubectl](#install-kubectl)
  - [Install Minikube](#install-minikube)
  - [Run Minikube](#run-minikube)
- [Deploying your first application](#deploying-your-first-application)
  - [What just happened?](#what-just-happened)
  - [Scaling your application](#scaling-your-application)
- [Persistent storage](#persistent-storage)
- [Ingress controller](#ingress-controller)
  - [Ingress Controller is Needed](#ingress-controller-is-needed)
  - [Why Nginx?](#why-nginx)
  - [Defaultbackend](#defaultbackend)
  - [Nginx-Ingress & defaultbackend](#nginx-ingress-and-defaultbackend)
  - [Simple Application](#simple-application)
  - [RC and Service](#rc-and-service)
  - [Multiple Services](#multiple-services)
  - [Configuring Ingress to Handle HTTPS traffic](#configuring-ingress-to-handle-https-traffic)
  - [Bonus 1 - Mapping Different Services to Different Hosts](#bonus-1---mapping-different-services-to-different-hosts)
  - [Bonus 2 - Use Minikube Addon to Enable Nginx Ingress](#bonus-2---use-minikube-addon-to-enable-nginx-ingress)

## Setup Minikube

! IMPORTANT ! VT-x or AMD-v virtualization must be enabled in your computer’s BIOS.

### Install Hypervisor
If you do not already have a hypervisor installed, install one now.
 - For OS X, install `VirtualBox` or `VMware Fusion`, or `HyperKit`.
 - For Linux, install `VirtualBox` or `KVM`.
 - For Windows, install `VirtualBox` or `Hyper-V`.

Note: Minikube also supports a --vm-driver=none option that runs the Kubernetes components on the host and not in a VM. Docker is required to use this driver but a hypervisor is not required.

### Install Kubectl
Install kubectl according to [this instructions](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

### Install Minikube
Install Minikube according to the instructions for the [release 0.28.0](https://github.com/kubernetes/minikube/releases/tag/v0.28.0)

### Run Minikube
If you want to change the VM driver add the appropriate `--vm-driver=xxx` flag to `minikube start`.

```
$ minikube start
Starting local Kubernetes cluster...
Running pre-create checks...
Creating machine...
Starting local Kubernetes cluster...

```
### Prepare Demo application
We're going to use a simple NodeJS application. The image is pushed to a DockerHub already (`prgcont/gordon:v1.0`) but you should never-ever download and run unknown images from DockerHub, so let's build it instead.

Here is the app:
```
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
If you're not familiar with NodeJS, this app basically answers with greetings and hostname to any request to port 8080.

Save it as `app-v1.js` and let's create a Dockerfile for it:
```
FROM node:10.5-slim
ADD app-v1.js /app-v1.js
EXPOSE 8080
ENTRYPOINT ["node", "app-v1.js"]
```
now build it:
```
$ export REGISTRY_USER=<your_name>
$ docker build -t ${REGISTRY_USER}/gordon:v1.0 .
```
And push it either to DockerHub or to your favorite Docker registry.

! IMPORTANT - All source code is [here](https://github.com/prgcont/workshop-k8s/tree/master/src/ingress)


## Deploying your first application

No as we have minikube and our application ready, we can deploy our application into minikube as easily as running following command:
```
$  kubectl run hello --image=${REGISTRY_USER}/gordon:v1.0 --port=8080 --expose
```

## What just happened?

We asked Kubernetes to deploy our previously build application and we hinted it, that it will be listening on port 8080 and we wanted it to be exposed to a cluster enabling
load balancing to work.

## How can I access my app?

To access your app we will hook inside Kubernetes network via `kubectl proxy` command, so please open a new terminal and run

```
$  kubectl proxy
```
! IMPORTANT - Do not stop proxy as following commands will not work.

Than you can access your application via following command:
```
curl http://localhost:8001/api/v1/namespaces/default/services/hello/proxy/
```

### Service
Did you note a world `service` inside the url? Yes, we are using kubernetes service to access our application. You can see how the service object looks by running:
```
$  kubectl describe service hello
```

Or you can list all other services by:
```
$  kubectl get services
```

Why service is there? The service is very important object in Kubernetes. Its an abstraction for your deployed applications. It helps you to discover your pods, to load balance them and
many other scenarios. You can learn more in upstream [doc](https://kubernetes.io/docs/concepts/services-networking/service/). You can imagine it in a following way:

```

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


### Pod
As you already know a group of containers running in a Kubernetes cluster is called `Pod`. So lets look which pods are running in our Kubernetes cluster by executing:

```
$  kubectl get pods

```

You can see how the Pod is defined by executing (replace `<pod_name>` by Pod name from previous output):

```
$ kubectl describe pod <pod_name>
```

you can even access Pod directly via `curl` by:

```
$  export POD_NAME=$(kubectl get pods | grep hello | cut -f 1 -d ' ' | head -n 1)
$  curl -L http://localhost:8001/api/v1/namespaces/default/pods/$PODNAME/proxy/
```


## Scaling your application
As we deployed our application via `kubectl run` command, it was created using `deployment` object, we can view it via:

```
$  kubectl describe deployment hello
```

Examine whole output, you can see a Pod template with our container image, and most important part for us a line with a word `Replicas`. This tells
Kubernetes how many instances of our application we want to have. We can scale our deployment by executing

```
$  kubectl scale --replicas=3 deployment/hello
```

This will ask our Deployment to scale our application to 3 instances. The number of instances is guarded by ReplicaSet. You can list and describe ReplicaSets by following commands
(replace ... by name of your ReplicaSet):

```
kubectl get rs
kubectl describe rs/...
```
*note:* You can still find people using Replication Controllers instead of Replica Set which is outdated approach and you should avoid it as both object works almost same with ReplicaSets enabling you
to use more advance [labels/selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#label-selectors) mechanisms.


When we list pods again we should see 3 of them:

```
$  kubectl get pods
```

And we can test, that all of the pods are being used by `curl` the service url (remember service is providing load balancing of pods) via:

```
$  for i in $(seq 1 50); do curl http://localhost:8001/api/v1/namespaces/default/services/hello/proxy/; done
```

### Tasks

1. How can service find its targeted pods?
2. Run `minikube dashboard` and find all the objects we described using the Kubernetes Dashboard


## Persistent storage

In this chapter we will look how we can add a persistent storage to our applications. This topic is very important as a lot of outstanding
application needs some storage access. We can argue, that we should not need any persistent storage and just consume API. But in real world
you will face a need of providing file-system like storage for your pods. Persistent volumes are ussually network filesystems. You can see
a list of supported providers at upstream [docs](https://kubernetes.io/docs/concepts/storage/volumes/#types-of-volumes)

### Claiming persistent volumes

Minikube comes with auto-provisioned persistent volumes, they are created as you ask for them. Any application which needs a persistent volume
must claim it. You can do it, by creating Persistent Volume Claim by executing following command:

```
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

```
$  kubectl get pvc
$  kubectl describe pvc testpvc
```

### Injecting PVC into your application.

To inject our Persistent volume claim into our application we need to edit its "deployment" object by executing:

```
kubectl edit deployment hello
```

than look for a following section:

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

and change it to look like:

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

```
kubectl exec -ti $POD_NAME touch /srv/test_file

```
Than you can check that other pods can see the data by executing following command for each pod:

```
kubectl exec -ti $POD_NAME ls /srv
```
and you should see test_file on every pod.

### Tasks
1. Scale your application to 0 replicas and run it again and show that data still persist
2. Scale your application to 0 pod and recreate pvc, will data exist? 
3. Explain why its different outcome for first two tasks. You can look at PVC [lifecycle](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#lifecycle-of-a-volume-and-claim)

## Ingress controller
*Ingress - the action or fact of going in or entering; the capacity or right of the entrance. Synonyms: entry, entrance, access, means of entry, admittance, admission;*

An API object that manages external access to the services in a cluster, typically HTTP.

Ingress can provide load balancing, SSL termination and name-based virtual hosting.

### Ingress Controller is needed
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

```YAML
---

apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
---


apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: default-http-backend
  labels:
    app: default-http-backend
  namespace: ingress-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: default-http-backend
  template:
    metadata:
      labels:
        app: default-http-backend
    spec:
      terminationGracePeriodSeconds: 60
      containers:
      - name: default-http-backend
        # Any image is permissible as long as:
        # 1. It serves a 404 page at /
        # 2. It serves 200 on a /healthz endpoint
        image: gcr.io/google_containers/defaultbackend:1.4
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 30
          timeoutSeconds: 5
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: 10m
            memory: 20Mi
          requests:
            cpu: 10m
            memory: 20Mi
---

apiVersion: v1
kind: Service
metadata:
  name: default-http-backend
  namespace: ingress-nginx
  labels:
    app: default-http-backend
spec:
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: default-http-backend
---

kind: ConfigMap
apiVersion: v1
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
  labels:
    app: ingress-nginx
---

kind: ConfigMap
apiVersion: v1
metadata:
  name: tcp-services
  namespace: ingress-nginx
---

kind: ConfigMap
apiVersion: v1
metadata:
  name: udp-services
  namespace: ingress-nginx
---

apiVersion: v1
kind: ServiceAccount
metadata:
  name: nginx-ingress-serviceaccount
  namespace: ingress-nginx

---

apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: nginx-ingress-clusterrole
rules:
  - apiGroups:
      - ""
    resources:
      - configmaps
      - endpoints
      - nodes
      - pods
      - secrets
    verbs:
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - services
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - "extensions"
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - ""
    resources:
        - events
    verbs:
        - create
        - patch
  - apiGroups:
      - "extensions"
    resources:
      - ingresses/status
    verbs:
      - update

---

apiVersion: rbac.authorization.k8s.io/v1beta1
kind: Role
metadata:
  name: nginx-ingress-role
  namespace: ingress-nginx
rules:
  - apiGroups:
      - ""
    resources:
      - configmaps
      - pods
      - secrets
      - namespaces
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - configmaps
    resourceNames:
      # Defaults to "<election-id>-<ingress-class>"
      # Here: "<ingress-controller-leader>-<nginx>"
      # This has to be adapted if you change either parameter
      # when launching the nginx-ingress-controller.
      - "ingress-controller-leader-nginx"
    verbs:
      - get
      - update
  - apiGroups:
      - ""
    resources:
      - configmaps
    verbs:
      - create
  - apiGroups:
      - ""
    resources:
      - endpoints
    verbs:
      - get

---

apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: nginx-ingress-role-nisa-binding
  namespace: ingress-nginx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: nginx-ingress-role
subjects:
  - kind: ServiceAccount
    name: nginx-ingress-serviceaccount
    namespace: ingress-nginx

---

apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: nginx-ingress-clusterrole-nisa-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: nginx-ingress-clusterrole
subjects:
  - kind: ServiceAccount
    name: nginx-ingress-serviceaccount
    namespace: ingress-nginx
---

apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-ingress-controller
  namespace: ingress-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ingress-nginx
  template:
    metadata:
      labels:
        app: ingress-nginx
    spec:
      serviceAccountName: nginx-ingress-serviceaccount
      containers:
        - name: nginx-ingress-controller
          image: quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.16.2
          args:
            - /nginx-ingress-controller
            - --default-backend-service=$(POD_NAMESPACE)/default-http-backend
            - --configmap=$(POD_NAMESPACE)/nginx-configuration
            - --tcp-services-configmap=$(POD_NAMESPACE)/tcp-services
            - --udp-services-configmap=$(POD_NAMESPACE)/udp-services
            - --publish-service=$(POD_NAMESPACE)/ingress-nginx
            - --annotations-prefix=nginx.ingress.kubernetes.io
          securityContext:
            capabilities:
                drop:
                - ALL
                add:
                - NET_BIND_SERVICE
            # www-data -> 33
            runAsUser: 33
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          ports:
          - name: http
            containerPort: 80
          - name: https
            containerPort: 443
          livenessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1

```

### Simple application
Conceptually, our setup should look like this:
```
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
Now let's create a ReplicationController and a service: they will be used by Ingress:
```
$ cat <<EOF | kubectl create -f -
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
      - image: <your_name>/gordon:v1.0
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
Don’t forget to change the image in the YAML file to your docker image:

```
...
containers:
- image: <name_of_your_image_goes_here>
  name: nodejs
...
```
Check that service is up and running:

```
$  kubectl get svc
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
gordon-service-v1   ClusterIP   10.111.33.157   <none>        80/TCP    1d
kubernetes          ClusterIP   10.96.0.1       <none>        443/TCP   6d
```

Great, now let's create our first version of ingress:

```
$ cat <<EOF | kubectl create -f -
kind: Ingress
metadata:
  name: gordon
spec:
  rules:
  # this ingress maps the gordon.example.com domain name to our service
  # you have to add gordon.example.com to /etc/hosts
  - host: gordon.example.com
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

- adding the hostname gordon.example.com into /etc/hosts (don't forget to delete it afterwards!)
- changing the hostname `gordon.example.com` to `gordon.example.com.<minikube's_ip>` in the previous YAML file - it will use [nip.io](http://nip.io/) service for resolving the hostname
- in case of production applications we will need to set up DNS resolving properly.

Check that ingress is available:
```
$ kubectl get ing
NAME      HOSTS                ADDRESS        PORTS     AGE
gordon    gordon.example.com   192.168.64.8   80        1h
```

Let's test our ingress:

```
$ for i in {1..10}; do curl http://gordon.example.com/v1; done
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

If you will try to request http://gordon.example.com it will give you a default backend's 404:

```
$ curl http://gordon.example.com
default backend - 404
```

This is because we have a rule only for /v1 path in our ingress YAML. An Ingress with no rules sends all traffic to a single default backend. Traffic is routed to your default backend if none of the Hosts in your Ingress match the Host in the request header, and/or none of the paths match the URL of the request.

The biggest advantage of using ingresses is their ability to expose multiple services through a single IP address, so let’s see how to do that.

### Multiple services
Let's create a second app, it's, basically, the same application with the slightly different output:

```
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
```
FROM node:10.5-slim
ADD app-v2.js /app-v2.js
ENTRYPOINT ["node", "app-v2.js"]
```
Build it:
```
$ docker build -t <your_name>/gordon:v2.0
```
And push it either to DockerHub or to Harbor (don't forget to tag it accordingly).

Let's create a second ReplicationController and a Service:
```
$ cat <<EOF | kubectl create -f -
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
      - image: <your_name>/gordon:v2.0
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
Again, don’t forget to change the `image` in the YAML file to your docker image.

Let's check our services:
```
$ kubectl get svc
NAME                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
default-http-backend   ClusterIP   10.98.23.177     <none>        80/TCP    1h
gordon-service-v1      ClusterIP   10.108.177.42    <none>        80/TCP    1h
gordon-service-v2      ClusterIP   10.105.110.160   <none>        90/TCP    1h
kubernetes             ClusterIP   10.96.0.1        <none>        443/TCP   4d
```
And here is our new ingress YAML file:
```
$ cat <<EOF | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: gordon
spec:
  rules:
  # this ingress maps the gordon.example.com domain name to our service
  # you have to add gordon.example.com to /etc/hosts
  - host: gordon.example.com
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
*Don't forget to change the line `  - host: gordon.example.com` in case you're using nip.io service for resolving*

Let's test it:
```
$ for i in {1..5}; do curl http://gordon.example.com/v1; done
You've hit gordon v1, my name is gordon-v1-btkvr
You've hit gordon v1, my name is gordon-v1-64hhw
You've hit gordon v1, my name is gordon-v1-z99d6
You've hit gordon v1, my name is gordon-v1-btkvr
You've hit gordon v1, my name is gordon-v1-64hhw

$ for i in {1..5}; do curl http://gordon.example.com/v2; done
Hey, I'm the next version of gordon; my name is gordon-v2-g6pll
Hey, I'm the next version of gordon; my name is gordon-v2-c78bh
Hey, I'm the next version of gordon; my name is gordon-v2-jn25s
Hey, I'm the next version of gordon; my name is gordon-v2-g6pll
Hey, I'm the next version of gordon; my name is gordon-v2-c78bh
```
It works!

### Configuring Ingress to Handle HTTPS traffic
Currently, the Ingress can handle incoming HTTPS connections, but it terminates the TLS connection and sends requests to the services unencrypted.
Since the Ingress terminates the TLS connection, it needs a TLS certificate and private key to do that.
The two need to be stored in a Kubernetes resource called a Secret.

Create a certificate, a key and save them into Kubernetes Secret:
```
$ openssl genrsa -out tls.key 2048
$ openssl req -new -x509 -key tls.key -out tls.cert -days 360 -subj '/CN=gordon.example.com'
$ kubectl create secret tls tls-secret --cert=tls.cert --key=tls.key
secret "tls-secret" created
```

Now let's change our ingress:
```
$ cat <<EOF | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: gordon
spec:
  tls:
  - hosts:
    - gordon.example.com
    secretName: tls-secret
  rules:
  # this ingress maps the gordon.example.com domain name to our service
  # you have to add gordon.example.com to /etc/hosts
  - host: gordon.example.com
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
*Don't forget to change the line `  - host: gordon.example.com` in case you're using nip.io service for resolving*

Let's test it:
```
$ curl http://gordon.example.com/v1
<html>
<head><title>308 Permanent Redirect</title></head>
<body bgcolor="white">
<center><h1>308 Permanent Redirect</h1></center>
<hr><center>nginx</center>
</body>
</html>


$ curl -k https://gordon.example.com/v1
You've hit gordon v1, my name is gordon-v1-64hhw
```

### Bonus 1 - Mapping Different Services to Different Hosts
Requests received by the controller will be forwarded to either service `foo` or `bar`, depending on the Host header in the request (exactly like how virtual hosts are handled in web servers).
Of course, DNS needs to point both the `foo.example.com` and the `bar.example.com` domain names to the Ingress controller’s IP address.

Example:
```
...
spec:
  rules:
  - host: foo.example.com
    http:
      paths:
      - path: /                
        backend:
          serviceName: foo
          servicePort: 80      
  - host: bar.example.com
    http:
      paths:
      - path: /                
        backend:
          serviceName: bar
          servicePort: 80
...
```

### Bonus 2 - Use Minikube Addon to Enable Nginx Ingress
```
$ minikube status
minikube: Running
cluster: Running
kubectl: Correctly Configured: pointing to minikube-vm at 192.168.64.8
```

```
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
```
$ minikube addons enable ingress
ingress was successfully enabled
```

Wait for a minute and then check that your cluster runs both nginx and default-http-backend:

nginx:
```
$ kubectl get all --all-namespaces | grep nginx
kube-system   deploy/nginx-ingress-controller   1         1         1            1           1h
kube-system   rs/nginx-ingress-controller-67956bf89d   1         1         1         1h
kube-system   po/nginx-ingress-controller-67956bf89d-dbbl4   1/1       Running   2          1h
```

default-backend:
```
$ kubectl get all --all-namespaces | grep default-http-backend
kube-system   deploy/default-http-backend       1         1         1            1           1h
kube-system   rs/default-http-backend-59868b7dd6       1         1         1         1h
kube-system   po/default-http-backend-59868b7dd6-6sh5f       1/1       Running   1          1h
kube-system   svc/default-http-backend   NodePort    10.104.42.209   <none>        80:30001/TCP    1h
```
