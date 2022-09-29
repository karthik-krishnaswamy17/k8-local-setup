#!/bin/bash
set -xv

if [[ $# -le 0 ]]
then
echo "Usage - setup.sh master|worker"
exit
fi


setup_cluster(){
sudo kubeadm init --pod-network-cidr 192.168.0.0/16 --kubernetes-version 1.23.0
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

setup_node(){
echo `hostname -I | cut -d " " -f1` `hostname` | sudo tee -a /etc/hosts
cat << EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system
sudo apt-get update && sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo swapoff -a
sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat << EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update
sudo apt-get install -y kubelet=1.23.0-00 kubeadm=1.23.0-00 kubectl=1.23.0-00
sudo apt-mark hold kubelet kubeadm kubectl
}

setup_network(){
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
kubeadm token create --print-join-command

}

if [[ $1 = "master" ]]
then
echo "Deploying script in Master node"
sudo hostnamectl set-hostname k8s-control
setup_node
setup_cluster
setup_network
else
if [[ $1 = "worker" ]]
then
echo " Deploying Script in Worker node"
sudo hostnamectl set-hostname k8s-worker1
setup_node
fi
fi

