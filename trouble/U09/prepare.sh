#!/bin/bash

for n in $(kubectl get no -o=custom-columns=NAME:.metadata.name --no-headers); do 
	kubectl cordon $n
done

kubectl apply -f U09.yml
kubectl delete po --all
