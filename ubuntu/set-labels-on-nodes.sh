#!/bin/sh

kubectl label nodes worker-1 environment=nonproduction 
kubectl label nodes worker-1 node-role.kubernetes.io/worker= 

kubectl label nodes worker-2 environment=production 
kubectl label nodes worker-2 node-role.kubernetes.io/worker= 

kubectl label nodes worker-3 router=interno.gov.teste
kubectl label nodes worker-3 node-role.kubernetes.io/infra= 

kubectl label nodes worker-4 router=externo.jus.teste
kubectl label nodes worker-4 node-role.kubernetes.io/infra= 

kubectl taint nodes worker-3 router-int=reserved:NoSchedule 
kubectl taint nodes worker-4 router-ext=reserved:NoSchedule 


