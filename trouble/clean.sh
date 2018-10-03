#!/bin/bash

# Remove resources
kubectl delete deploy,sts,svc,cm,secret,pvc --grace-period=0 --all


# Clean nodes
for n in $(kubectl get no -o=custom-columns=NAME:.metadata.name --no-headers); do
	kubectl uncordon $n;

	# Remove labels project
	kubectl label nodes $n project- 
	
	# Remove taints 
	kubectl taint nodes --all dirty-
done

kubectl get no,all,cm,secret,pvc
