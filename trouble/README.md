This repository containers common Kubernetes problems. Each YAML file (or directory) contains broken deployment.

* `clean.sh` will clean everything in `default` namespaces and fix broken nodes.


# Easy

* U01 - Scaled to 0 replicas
* U02 - Wrong service selector (application instead of app)
* U03 - Typo in container image
* U09 - Nodes unschedulable

# Medium

* U04 - ConfigMap missing
* U05 - Persistent volume claim missing
* U06 - Missing node label (nodeSelector)
* U08 - Service port mismatch
* U09 - Nodes unschedulable
* U10 - Nodes tainted
* U11 - InitContainer failing
* U12 - Liveness probe not working (port mismatch)
