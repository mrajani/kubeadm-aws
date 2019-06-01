#!/bin/bash -v

curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl kubernetes-cni
curl -sSL https://get.docker.com/ | sh
systemctl start docker

sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1

# cat <<EOF > /tmp/kubeadm-config.yaml
# apiVersion: kubeadm.k8s.io/v1beta1
# kind: InitConfiguration
# bootstrapTokens:
# - groups:
#   - system:bootstrappers:kubeadm:default-node-token
#   token: ${k8stoken}
# nodeRegistration:
#   name: $(hostname -f)
# ---
# apiVersion: kubeadm.k8s.io/v1beta1
# kind: ClusterConfiguration
# dns:
#   type: kube-dns
# networking:
#   podSubnet: 172.20.0.0/16
#   serviceSubnet: 10.96.0.0/12
# apiServer:
#   extraArgs:
#     enable-admission-plugins: DefaultStorageClass,NodeRestriction
# #    cloud-provider: aws
# controllerManager:
#   extraArgs:
#     cloud-provider: aws
#     configure-cloud-routes: "false"
#     address: 0.0.0.0
# EOF

cat <<EOF > /tmp/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta1
kind: InitConfiguration
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: ${k8stoken}
nodeRegistration:
  name: $(hostname -f)
---
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
controllerManager:
  extraArgs:
    cloud-provider: aws
    configure-cloud-routes: "false"
    address: 0.0.0.0
apiServer:
  extraArgs:
    cloud-provider: aws
networking:
  podSubnet: 192.168.0.0/16
  serviceSubnet: 10.96.0.0/12
EOF

#kubeadm init --config=/tmp/kubeadm-config.yaml --node-name=$(hostname -f)
kubeadm init --config=/tmp/kubeadm-config.yaml --node-name=$(hostname -f)
#

echo "KUBELET_KUBEADM_ARGS=--cloud-provider=aws --cgroup-driver=cgroupfs --pod-infra-container-image=k8s.gcr.io/pause:3.1 --network-plugin=cni --hostname-override=$(hostname).ec2.internal" > /var/lib/kubelet/kubeadm-flags.env
# echo "KUBELET_KUBEADM_ARGS=--cloud-provider=aws --cgroup-driver=cgroupfs --hostname-override=$(hostname).ec2.internal --network-plugin=cni --pod-infra-container-image=k8s.gcr.io/pause:3.1"  > /var/lib/kubelet/kubeadm-flags.env
#echo "KUBELET_KUBEADM_ARGS=--cloud-provider=aws --cgroup-driver=cgroupfs --pod-infra-container-image=k8s.gcr.io/pause:3.1" > /var/lib/kubelet/kubeadm-flags.env
systemctl restart kubelet



export KUBECONFIG=/etc/kubernetes/admin.conf
# echo "hello"
# Configure kubectl.
mkdir -p /home/ubuntu/.kube
sudo cp -i $KUBECONFIG /home/ubuntu/.kube/config
sudo chown ubuntu: /home/ubuntu/.kube/config

kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml

# https://blog.heptio.com/setting-up-the-kubernetes-aws-cloud-provider-6f0349b512bd
# in order for load balancers to work, you'll need to patch the WORKER node:
# kubectl patch node ip-10-0-100-63.ec2.internal -p '{"spec":{"providerID":"aws:///us-east-1c/i-08f869d8f2be01d98"}}'


# KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter-all-features.yaml
# KUBECONFIG=/etc/kubernetes/admin.conf kubectl -n kube-system delete ds kube-proxy
# docker run --privileged -v /lib/modules:/lib/modules --net=host k8s.gcr.io/kube-proxy-amd64:v1.13.2 kube-proxy --cleanup

# kubectl get cm -n kube-system kube-proxy -oyaml | sed -r '/^\s+resourceVersion:/d' | sed 's/masqueradeAll: false/masqueradeAll: true/' | kubectl replace -f -

# kubectl patch -n kube-system deployment kube-dns --patch '{"spec": {"template": {"spec": {"tolerations": [{"key": "CriticalAddonsOnly", "operator": "Exists"}]}}}}'

# cat <<EOF > /tmp/storageclass.yaml
# kind: StorageClass
# apiVersion: storage.k8s.io/v1
# metadata:
#   name: ebs
#   annotations:
#     storageclass.kubernetes.io/is-default-class: "true"
# provisioner: kubernetes.io/aws-ebs
# volumeBindingMode: Immediate
# reclaimPolicy: Retain
# EOF
# kubectl apply -f /tmp/storageclass.yaml
