#!/bin/bash

k8s-worker_install_general_utilities() {
    printf -- 'Installing general utilities\n'
    printf -- '----------------------------\n'
    sudo yum install vim -y
    sudo yum install iproute-tc -y
    printf -- '\n'
}

k8s-worker_setup_network() {
    printf -- 'Preparing the network\n'
    printf -- '---------------------\n'
    sudo modprobe overlay
    sudo modprobe br_netfilter
    printf -- '%s\n' 'net.bridge.bridge-nf-call-iptables  = 1' \
                     'net.bridge.bridge-nf-call-ip6tables = 1'  \
                     'net.ipv4.ip_forward                 = 1' | sudo tee /etc/sysctl.d/99-k8s.conf
    sudo sysctl --system
    # For some unknown reason the br_netfilter doesn't load
    # automatically on system boot and because of this we 
    # need to force it
    printf -- '%s\n' '# Load br_netfilter.ko at boot' \
                     'br_netfilter' | sudo tee /etc/modules-load.d/br_netfilter.conf
    printf -- '\n'
}

k8s-worker_disable_selinux() {
    printf -- 'Disabling SELinux\n'
    printf -- '-----------------\n'
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=enforcing$/SELINUX=disable/' /etc/selinux/config
    printf -- '\n'
}

k8s-worker_disable_swap() {
    printf -- 'Disabling swap\n'
    printf -- '--------------\n'
    sudo swapoff -a
    sudo sed --in-place 's|^/dev/mapper/vg_main-lv_swap|#/dev/mapper/vg_main-lv_swap|' /etc/fstab
    printf -- '\n'
}

k8s-worker_disable_firewall() {
    printf -- 'Disabling firewall\n'
    printf -- '------------------\n'
    sudo systemctl stop firewalld
    sudo systemctl disable firewalld
    printf -- '\n'
}

k8s-worker_install_container_runtime() {
    printf -- 'Installing container runtime CRI-O\n'
    printf -- '----------------------------------\n'
    export VERSION=1.19
    export OS=CentOS_8
    sudo curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/devel:kubic:libcontainers:stable.repo
    sudo curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo
    sudo yum install cri-o -y
    sudo systemctl enable crio
    sudo systemctl start crio
    printf -- '\n'
}

k8s-worker_install_kubeadm_kubelet_kubectl() {
    printf -- 'Installing kubeadm and kubelet\n'
    printf -- '------------------------------\n'
    printf -- '%s\n' '[kubernetes]' \
                     'name=Kubernetes' \
                     'baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64' \
                     'enabled=1' \
                     'gpgcheck=1' \
                     'repo_gpgcheck=1' \
                     'gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg' \
                     'exclude=kubelet kubeadm' | tee /etc/yum.repos.d/kubernetes.repo
    sudo yum install -y kubelet kubeadm --disableexcludes=kubernetes
    sudo sed --in-place 's/Wants=network-online\.target/Wants=network-online\.target crio\.service/' /usr/lib/systemd/system/kubelet.service
    sudo systemctl enable kubelet # Do not start the service because this is done by kubeadm
    printf -- '\n'
}

k8s-worker_join_node() {
    printf -- 'Joining node to K8s cluster\n'
    printf -- '---------------------------\n'
    sudo su -c '/vagrant/join_worker.sh'
    printf -- '\n'
}

# This script can be debugged the following way
# Comment out all functions that shouldn't be called
# Call the script with: sudo su -c '/vagrant/setup_worker.sh'
printf -- '---------------------------------------------------------------------------\n'
printf -- 'Installing kubernetes worker node and joining it to cluster                \n'
printf -- 'See: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm \n'
printf -- '---------------------------------------------------------------------------\n'
printf -- '\n'

k8s-worker_install_general_utilities
k8s-worker_setup_network
k8s-worker_disable_selinux
k8s-worker_disable_swap
k8s-worker_disable_firewall
k8s-worker_install_container_runtime
k8s-worker_install_kubeadm_kubelet_kubectl
k8s-worker_join_node
