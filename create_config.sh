#!/bin/bash

openssl genrsa -out sts-check.key 2048
openssl req -new -key sts-check.key -out sts-check.csr -subj "/CN=sts-check"
kubectl delete csr sts-check
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: sts-check
spec:
  request: $(cat sts-check.csr | base64 | tr -d "\n") 
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 8640000  # 1k days
  usages:
  - client auth
EOF
kubectl get csr
kubectl certificate approve sts-check
sleep 3
kubectl get csr/sts-check -o yaml
kubectl get csr sts-check -o jsonpath='{.status.certificate}'| base64 -d > sts-check.crt
kubectl create role sts-check --verb=get --verb=list --verb=update --resource=pods
kubectl create rolebinding sts-check-binding --role=sts-check --user=sts-check
kubectl config set-credentials sts-check --client-key=sts-check.key --client-certificate=sts-check.crt --embed-certs=true
kubectl config set-context sts-check --cluster=cluster1 --user=sts-check
kubectl config use-context sts-check
kubectl config view --raw=true --flatten=true > /root/.kube/config-sts-check
KUBECONFIG=/root/.kube/config-sts-check kubectl delete pod nginx
KUBECONFIG=/root/.kube/config-sts-check kubectl run nginx --image=nginx

