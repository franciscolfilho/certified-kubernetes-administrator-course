#!/bin/sh

sudo snap install helm --classic && \
helm repo add haproxytech https://haproxytech.github.io/helm-charts && \
helm repo update

#--- https://artifacthub.io/packages/helm/haproxy-ingress/haproxy-ingress

helm install --create-namespace --namespace=ingress-controller-interno haproxy-ingress-controller-interno haproxytech/kubernetes-ingress \
    --set controller.ingressClass=haproxy-interno \
    --set controller.nodeSelector.router=interno.gov.teste \
    --set controller.nodeSelector."node-role\.kubernetes\.io/infra"= \
    --set defaultBackend.nodeSelector."node-role\.kubernetes\.io/infra"= \
    --set defaultBackend.nodeSelector.router=interno.gov.teste \
    --set-string "controller.config.syslog-server=address:stdout\, format:raw\, facility:daemon" \
    --set controller.tolerations[0].key="router-int" \
    --set controller.tolerations[0].value="reserved" \
    --set controller.tolerations[0].effect="NoSchedule" \
    --set defaultBackend.tolerations[0].key="router-int" \
    --set defaultBackend.tolerations[0].value="reserved" \
    --set defaultBackend.tolerations[0].effect="NoSchedule"

helm install --create-namespace --namespace=ingress-controller-externo haproxy-ingress-controller-externo haproxytech/kubernetes-ingress \
    --set controller.ingressClass=haproxy-externo \
    --set controller.nodeSelector.router=externo.jus.teste \
    --set controller.nodeSelector."node-role\.kubernetes\.io/infra"= \
    --set defaultBackend.nodeSelector."node-role\.kubernetes\.io/infra"= \
    --set defaultBackend.nodeSelector.router=externo.jus.teste \
    --set-string "controller.config.syslog-server=address:stdout\, format:raw\, facility:daemon" \
    --set controller.tolerations[0].key="router-ext" \
    --set controller.tolerations[0].value="reserved" \
    --set controller.tolerations[0].effect="NoSchedule" \
    --set defaultBackend.tolerations[0].key="router-ext" \
    --set defaultBackend.tolerations[0].value="reserved" \
    --set defaultBackend.tolerations[0].effect="NoSchedule"

## Criando certificado wildcard auto-assinado
openssl req -x509 \
  -sha256 \
  -newkey rsa:2048 \
  -keyout private-gov.teste.key \
  -out cert-gov.teste.crt \
  -days 365 \
  -nodes \
  -subj "/CN=haproxy-router-int.gov.teste" \
  -addext "subjectAltName = DNS:*.gov.teste" 

openssl req -x509 \
  -sha256 \
  -newkey rsa:2048 \
  -keyout private-jus.teste.key \
  -out cert-jus.teste.crt \
  -days 365 \
  -nodes \
  -subj "/CN=haproxy-router-ext.jus.teste" \
  -addext "subjectAltName = DNS:*.jus.teste"
  
## Criando a secret contendo o certificado
kubectl create secret tls wildcard-cert-gov-secret -n ingress-controller-interno \
  --key="private-gov.teste.key" \
  --cert="cert-gov.teste.crt"

kubectl create secret tls wildcard-cert-jus-secret -n ingress-controller-externo \
  --key="private-jus.teste.key" \
  --cert="cert-jus.teste.crt"
  
## Gerando patch do configmap para redefinir o certificado a ser utilizado
cat << EOF > patch-configmap-certificate-gov.yaml
data:
  ssl-certificate: "ingress-controller-interno/wildcard-cert-gov-secret"
EOF

cat << EOF > patch-configmap-certificate-jus.yaml
data:
  ssl-certificate: "ingress-controller-externo/wildcard-cert-jus-secret"
EOF

kubectl patch configmap haproxy-ingress-controller-interno-kubernetes-ingress -n ingress-controller-interno --patch "$(cat patch-configmap-certificate-gov.yaml)"

kubectl patch configmap haproxy-ingress-controller-externo-kubernetes-ingress -n ingress-controller-externo --patch "$(cat patch-configmap-certificate-jus.yaml)"

##
