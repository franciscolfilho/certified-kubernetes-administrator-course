#!/bin/bash

#####################################################################################################################
#  PodNodeSelector:
#  --------------
#    * Allows forcing pods to run on specifically labeled nodes;
#
#    * THIS ADMISSION CONTROLLER DEFAULTS AND LIMITS WHAT NODE SELECTORS MAY BE USED WITHIN A NAMESPACE
#       BY READING A NAMESPACE ANNOTATION AND A GLOBAL CONFIGURATION.
#
#    * You can define a default selector for namespaces that have no label selector specified
#
#    * Ultimately, it gives the cluster administrator more control over the node selection process (hard enforcement)
#
# 
## Referências:
## - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/_print/#pg-4c656c5eda3e1c06ad1aedebdc04a211
## - https://pkg.go.dev/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2
#
#######################################################################################################################


INTERNAL_IP=$(ip addr show enp0s8 | grep "inet " | awk '{print $2}' | cut -d / -f 1) 
LOADBALANCER_ADDRESS=$(grep lb /etc/hosts | awk '{print $1}') 

ADMISSION_CONTROL_CONFIG_FILE="/vagrant/admission-control.yaml"
PODNODESELECTOR_CONFIG_FILE="/vagrant/podnodeselector.yaml"

sudo tee ${PODNODESELECTOR_CONFIG_FILE} <<EOF
podNodeSelectorPluginConfig:
  clusterDefaultNodeSelector: "environment=nonproduction"
  echoserver-desenvolvimento: "environment=nonproduction"
  echoserver-producao: "environment=production"
EOF

sudo tee ${ADMISSION_CONTROL_CONFIG_FILE} <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodNodeSelector
  path: ${PODNODESELECTOR_CONFIG_FILE}
EOF

sudo tee ${KUBEADM_INIT_CONFIG_FILE} <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "${INTERNAL_IP}"
  bindPort: 6443
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: ${KUBERNETES_VERSION}
controlPlaneEndpoint: "${LOADBALANCER_ADDRESS}:6443"
networking:
  podSubnet: "10.244.0.0/16"
apiServer:
  extraArgs:
    advertise-address: ${INTERNAL_IP}
    enable-admission-plugins: NodeRestriction,PodNodeSelector
    admission-control-config-file: ${ADMISSION_CONTROL_CONFIG_FILE}
  extraVolumes:
    - name: admission-file
      hostPath: ${ADMISSION_CONTROL_CONFIG_FILE}
      mountPath: ${ADMISSION_CONTROL_CONFIG_FILE}
      readOnly: true
    - name: podnodeselector-file
      hostPath: ${PODNODESELECTOR_CONFIG_FILE}
      mountPath: ${PODNODESELECTOR_CONFIG_FILE}
      readOnly: true
EOF

kubectl get nodes

let minutes=0
let timeout=5
while [ true ]
do
   ## Checa status do node
    nodeReadyStatus=$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{end}')
    [[ "$nodeReadyStatus" = "True" ]] && break;

    [[ ${minutes} -eq 5 ]] && { echo "ERROR: Timeout reached $minutes minutes"; exit 1; }

    sleep 1m
    let minutes=minutes+1
done

#sudo kubeadm reset -f
sudo kubeadm init phase control-plane apiserver --config=${KUBEADM_INIT_CONFIG_FILE}
