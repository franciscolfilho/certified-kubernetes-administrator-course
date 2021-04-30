#!/bin/sh

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

ADMISSION_CONTROL_CONFIG_FILE="/vagrant/admission-control.yaml"
PODNODESELECTOR_CONFIG_FILE="/vagrant/podnodeselector.yaml"
KUBEADM_INIT_CONFIG_FILE="/vagrant/kube_init_config.yaml"

INTERNAL_IP=$(ip addr show enp0s8 | grep "inet " | awk '{print $2}' | cut -d / -f 1) 
LOADBALANCER_ADDRESS=$(grep lb /etc/hosts | awk '{print $1}') 
KUBEADM_INIT_STDOUT="/vagrant/kubeadm_init.out"

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


#sudo kubeadm init --config=${KUBEADM_INIT_CONFIG_FILE} \
#  --upload-certs \
#  --ignore-preflight-errors=Mem | tee ${KUBEADM_INIT_STDOUT}


sudo kubeadm init --apiserver-advertise-address=${INTERNAL_IP} \
  --pod-network-cidr=10.244.0.0/16 \
  --control-plane-endpoint "${LOADBALANCER_ADDRESS}:6443" \
  --upload-certs \
  --ignore-preflight-errors=Mem | tee ${KUBEADM_INIT_STDOUT}

sudo kubeadm init phase control-plane apiserver --config=${KUBEADM_INIT_CONFIG_FILE}

KUBE_DIR_PATH="$HOME/.kube"
mkdir -p ${KUBE_DIR_PATH}
sudo cp -v /etc/kubernetes/admin.conf "${KUBE_DIR_PATH}/config"
sudo chown $(id -u):$(id -g) "${KUBE_DIR_PATH}/config" 

## ====  O procedimento abaixo não faz parte da instalação do node master-1 =====

## Recupera os comando de join para os nodes master restantes, e também para os worker nodes
SCRIPT_JOIN_MASTER="/vagrant/control_plane_join_command.sh"
SCRIPT_JOIN_WORKER="/vagrant/worker_node_join_command.sh"
TMP_FILE="/tmp/out"
grep -E -B2  '^.*\--control-plane.*$' ${KUBEADM_INIT_STDOUT} | tee ${SCRIPT_JOIN_MASTER} | head -2 | tee ${SCRIPT_JOIN_WORKER}
#

## Realiza ajustes no comando de join dos masters
echo 'INTERNAL_IP=$(ip addr show enp0s8 | grep "inet " | awk "{print \$2}" | cut -d / -f 1)' | cat - ${SCRIPT_JOIN_MASTER} > ${TMP_FILE} && mv ${TMP_FILE} ${SCRIPT_JOIN_MASTER}
sed -i  '$s/$/ \\/' ${SCRIPT_JOIN_MASTER} # Adiciona um ' \' na última linha
echo '--apiserver-advertise-address=${INTERNAL_IP} \' >> ${SCRIPT_JOIN_MASTER}
echo '--ignore-preflight-errors=Mem' >> ${SCRIPT_JOIN_MASTER}
#

