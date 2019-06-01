#!/bin/bash -v

curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl kubernetes-cni python python-pip jq

# Install docker so kubeadm won't complain.
curl -sSL https://get.docker.com/ | sh
systemctl start docker

modprobe br_netfilter
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.ipv4.ip_forward=1

# wget https://download.elotl.co/milpa-installer-latest
# chmod 755 milpa-installer-latest
# ./milpa-installer-latest

# pip install yq
# yq -y ".clusterName=\"${cluster_name}\" | .cloud.aws.accessKeyID=\"${aws_access_key_id}\" | .cloud.aws.secretAccessKey=\"${aws_secret_access_key}\" | .cloud.aws.vpcID=\"\" | .license.key=\"${license_key}\" | .license.id=\"${license_id}\" | .license.username=\"${license_username}\" | .license.password=\"${license_password}\"" /opt/milpa/etc/server.yml > /opt/milpa/etc/server.yml.new && mv /opt/milpa/etc/server.yml.new /opt/milpa/etc/server.yml
# sed -i 's#--milpa-endpoint 127.0.0.1:54555$#--milpa-endpoint 127.0.0.1:54555 --non-masquerade-cidr 10.96.0.0/12 --kubeconfig /etc/kubernetes/kubelet.conf#' /etc/systemd/system/kiyot.service
# sed -i 's#--config /opt/milpa/etc/server.yml$#--config /opt/milpa/etc/server.yml --delete-cluster-lock-file#' /etc/systemd/system/milpa.service
# mkdir -p /etc/systemd/system/kubelet.service.d/
# echo -e "[Service]\nStartLimitInterval=0\nStartLimitIntervalSec=0\nRestart=always\nRestartSec=5" > /etc/systemd/system/kubelet.service.d/override.conf

for i in {1..50}; do kubeadm join --discovery-token-unsafe-skip-ca-verification --token=${k8stoken} ${masterIP}:6443 --node-name=$(hostname -f) && break || sleep 15; done

echo "KUBELET_KUBEADM_ARGS=--cloud-provider=aws --cgroup-driver=cgroupfs --pod-infra-container-image=k8s.gcr.io/pause:3.1 --network-plugin=cni --hostname-override=$(hostname).ec2.internal" > /var/lib/kubelet/kubeadm-flags.env

#echo "KUBELET_KUBEADM_ARGS=--cloud-provider=aws --pod-infra-container-image=k8s.gcr.io/pause:3.1 --max-pods=1000" > /var/lib/kubelet/kubeadm-flags.env
systemctl restart kubelet

#systemctl daemon-reload
#systemctl restart milpa
#systemctl restart kiyot
#systemctl restart kubelet

# docker ps -aq --no-trunc | xargs docker stop
# docker ps -aq --no-trunc | xargs docker rm
