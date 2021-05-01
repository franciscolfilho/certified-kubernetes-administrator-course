#!/bin/sh

KUBEADM_INIT_CONFIG_FILE="/vagrant/kube_init_config.yaml"

INTERNAL_IP=$(ip addr show enp0s8 | grep "inet " | awk '{print $2}' | cut -d / -f 1) 
LOADBALANCER_ADDRESS=$(grep lb /etc/hosts | awk '{print $1}') 
KUBEADM_INIT_STDOUT="/vagrant/kubeadm_init.out"

sudo kubeadm init --apiserver-advertise-address=${INTERNAL_IP} \
  --pod-network-cidr=10.244.0.0/16 \
  --control-plane-endpoint "${LOADBALANCER_ADDRESS}:6443" \
  --upload-certs \
  --ignore-preflight-errors=Mem | tee ${KUBEADM_INIT_STDOUT}


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

