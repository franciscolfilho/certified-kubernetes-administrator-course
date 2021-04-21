#!/bin/sh

sudo apt-get update && \
sudo apt-get install -y haproxy

ROUTER_INT_ADDRESS=$(grep worker-3 /etc/hosts | awk '{print $1}') && \

sudo tee /etc/haproxy/haproxy.cfg <<EOF
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

frontend http_request
    bind *:80
    mode tcp
    log global

    acl ACL_gov.teste hdr_end(host) -i gov.teste

    use_backend ingress-controller-interno-http if ACL_gov.teste

frontend https_request
    bind *:443
    mode tcp
    log global
    option tcplog
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }

    ## Opção 1
    use_backend ingress-controller-interno-https if { req.ssl_sni -m dom gov.teste }
    ## Opção 2
    #use_backend ingress-controller-interno-https if { req.ssl_sni -m end gov.teste }

backend ingress-controller-interno-http
    mode tcp
    server router-int-http ${ROUTER_INT_ADDRESS}:32089 check

backend ingress-controller-interno-https
    mode tcp
    server router-int-https ${ROUTER_INT_ADDRESS}:31574 check
EOF

sudo systemctl restart haproxy.service
