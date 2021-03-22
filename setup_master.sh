#!/bin/bash

k8s_install_general_utilities() {
    printf 'Installing general utilities\n'
    printf -- '----------------------------\n'
    sudo yum install vim -y
    sudo yum install iproute-tc -y
    printf -- '\n'
}

k8s_setup_network() {
    printf 'Preparing the network\n'
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

k8s_disable_selinux() {
    printf 'Disabling SELinux\n'
    printf -- '-----------------\n'
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=enforcing$/SELINUX=disable/' /etc/selinux/config
    printf -- '\n'
}

k8s_disable_swap() {
    printf 'Disabling swap\n'
    printf -- '--------------\n'
    sudo swapoff -a
    sudo sed --in-place 's|^/dev/mapper/vg_main-lv_swap|#/dev/mapper/vg_main-lv_swap|' /etc/fstab
    printf -- '\n'
}

k8s_disable_firewall() {
    printf 'Disabling firewall\n'
    printf -- '------------------\n'
    sudo systemctl stop firewalld
    sudo systemctl disable firewalld
    printf -- '\n'
}

k8s_install_container_runtime() {
    printf 'Installing container runtime CRI-O\n'
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

k8s_install_kubeadm_kubelet_kubectl() {
    printf -- 'Installing kubeadm, kubelet and kubectl\n'
    printf -- '---------------------------------------\n'
    printf -- '%s\n' '[kubernetes]' \
                     'name=Kubernetes' \
                     'baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64' \
                     'enabled=1' \
                     'gpgcheck=1' \
                     'repo_gpgcheck=1' \
                     'gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg' \
                     'exclude=kubelet kubeadm kubectl' | tee /etc/yum.repos.d/kubernetes.repo
    sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    sudo sed --in-place 's/Wants=network-online\.target/Wants=network-online\.target crio\.service/' /usr/lib/systemd/system/kubelet.service
    sudo systemctl enable kubelet # Do not start the service because this is done by kubeadm
    printf -- '\n'
}

k8s_download_control_plane_images() {
    printf 'Downloading control plane images\n'
    printf -- '--------------------------------\n'
    sudo kubeadm config images pull
    printf -- '\n'
}

k8s_install_control_plane() {
    printf -- 'Starting control plane installation\n'
    printf -- '-----------------------------------\n'
    # A config file needs to be used with kubeadm init because 
    # that is the only way to tell kubeadm the cgroup driver for
    # container runtimes other than docker
    #See: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#configure-cgroup-driver-used-by-kubelet-on-control-plane-node
    sudo kubeadm init --config=/vagrant/k8s_init_config.yaml | tee k8s_setup.log
    printf -- '\n'
}

k8s_handle_bug_79245() {
    # Kubelet couldn't run because of the following: failed to get the kubelet's cgroup: cpu and memory cgroup hierarchy not unified.
    # printf 'Work around for issue #79245\n'
    # printf -- '----------------------------\n'
    # See: https://github.com/kubernetes/kubernetes/pull/79245
    sudo mkdir -p /etc/systemd/system/kubelet.service.d
    printf -- '%s\n' '[Service]' \
                     'CPUAccounting=true' \
                     'MemoryAccounting=true' | tee /etc/systemd/system/kubelet.service.d/11-cgroups.conf
    sudo systemctl daemon-reload
    sudo systemctl restart kubelet
    printf -- '\n'
}

k8s_temporarily_enable_kubectl() {
    printf 'Temporarily setting KUBECONFIG to be able to run kubectl\n'
    printf -- '------------------------------------------------------\n'
    export KUBECONFIG=/etc/kubernetes/admin.conf
    printf -- '\n'
}

k8s_create_script_for_workers() {
    # For some unknown reason the sed command for grepping
    # the join command didn't work when executed by vagrant
    # Because of this I create the token manualy and redirect
    # the output into a textfile which works as expected
    printf 'Creating script for joining worker nodes\n'
    printf -- '----------------------------------------\n'
    sudo kubeadm token create --print-join-command | tee /vagrant/join_worker.sh
    printf -- '\n'
}

k8s_allow_vagrant_user_administration() {
    printf 'Allowing the vagrant user the administration of the cluster\n'
    printf -- '-----------------------------------------------------------\n'
    sudo mkdir -p /home/vagrant/.kube
    sudo cp --force /etc/kubernetes/admin.conf /home/vagrant/.kube/config
    sudo chown -R vagrant:vagrant /home/vagrant/.kube/config
    printf -- '\n'
}

k8s_install_pod_network() {
    printf 'Installing flannel pod network\n'
    printf -- '------------------------------\n'
    cat /vagrant/kube-flannel.yml | kubectl create -f -
    printf -- '\n'

    # Install calico
    # Download manifest: curl https://docs.projectcalico.org/manifests/calico.yaml -O
    # Apply manifest: kubectl apply -f calico.yaml
}

k8s_reset_worker() {
    printf -- 'Reseting worker node to a clean state\n'
    printf -- '-------------------------------------\n'
    if [ -f "/usr/bin/kubeadm" ]
    then
        sudo kubeadm reset --force
    fi
}

# This script can be debugged the following way
# Comment out all functions that shouldn't be called
# Call the script with: sudo su -c '/vagrant/setup_master.sh'
printf -- '---------------------------------------------------------------------------\n'
printf -- 'Bootstraping the cluster with kubeadm                                      \n'
printf -- 'See: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm \n'
printf -- '---------------------------------------------------------------------------\n'
printf -- '\n'

# To be able to run the initialization multiple times
# we reset this node so we can be sure that we start 
# in a clean environment
k8s_reset_worker

k8s_install_general_utilities
k8s_install_network_tools
k8s_setup_network
k8s_disable_selinux
k8s_disable_swap
k8s_disable_firewall
k8s_install_container_runtime
k8s_install_kubeadm_kubelet_kubectl
k8s_download_control_plane_images
k8s_install_control_plane
# Probably not necessary: k8s_handle_bug_79245
k8s_temporarily_enable_kubectl
k8s_create_script_for_workers
k8s_allow_vagrant_user_administration
k8s_install_pod_network
