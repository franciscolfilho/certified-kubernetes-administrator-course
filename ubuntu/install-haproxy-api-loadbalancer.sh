#!/bin/sh

sudo apt-get update && \
sudo apt-get install -y haproxy && \

LOADBALANCER_ADDRESS=$(grep lb /etc/hosts | awk '{print $1}') && \
MASTER1_ADDRESS=$(grep master-1 /etc/hosts | awk '{print $1}') && \
MASTER2_ADDRESS=$(grep master-2 /etc/hosts | awk '{print $1}') && \
MASTER3_ADDRESS=$(grep master-3 /etc/hosts | awk '{print $1}') && \


cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    ssl-server-verify none
    user    haproxy
    group   haproxy
    daemon

defaults
    log global
    timeout client 60s
    timeout server 60s
    timeout connect 10s

frontend kubernetes
    bind ${LOADBALANCER_ADDRESS}:6443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes

backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
    server master-1 ${MASTER1_ADDRESS}:6443 check fall 3 rise 2
    server master-2 ${MASTER2_ADDRESS}:6443 check fall 3 rise 2
    server master-3 ${MASTER3_ADDRESS}:6443 check fall 3 rise 2
EOF

sudo systemctl restart haproxy.service
