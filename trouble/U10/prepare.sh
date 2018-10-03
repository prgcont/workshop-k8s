#!/bin/bash
kubectl taint nodes --overwrite --all dirty=true:NoSchedule

kubectl apply -f U10.yml
kubectl delete po --all
