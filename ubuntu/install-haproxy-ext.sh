#!/bin/sh

sudo apt-get update && \
sudo apt-get install -y haproxy

ROUTER_EXT_ADDRESS=$(grep worker-4 /etc/hosts | awk '{print $1}') && \

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

    acl ACL_jus.teste hdr_end(host) -i jus.teste

    use_backend ingress-controller-externo-http if ACL_jus.teste

frontend https_request
    bind *:443
    mode tcp
    log global
    option tcplog
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }

    use_backend ingress-controller-externo-https if { req.ssl_sni -m dom jus.teste }

backend ingress-controller-externo-http
    mode tcp
    server router-ext-http ${ROUTER_EXT_ADDRESS}:32478 check

backend ingress-controller-externo-https
    mode tcp
    server router-ext-https ${ROUTER_EXT_ADDRESS}:32706 check
EOF

sudo systemctl restart haproxy.service
