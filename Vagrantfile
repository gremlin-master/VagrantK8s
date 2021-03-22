# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  # General settings that are available for all kubernetes VMs
  config.vm.provider "virtualbox" do |vb|
    # Changes to prevent the warnings dialog about invalid settings
    vb.customize ["modifyvm", :id, "--vram", "16"]
    vb.customize ["modifyvm", :id, "--graphicscontroller", "VMSVGA"]
    vb.customize ["modifyvm", :id, "--vrde", "off"]

    # Put the vm in an own group to have a clean separation to already existing VMs
    # BEWARE: Grouping isn't shown until the gui is closed and reopened: https://www.virtualbox.org/ticket/11500
    # Image for documentation: vbox_k8s_vms_in_group.png
    vb.customize ["modifyvm", :id, "--groups", "/Kubernetes"]
  end

  # Create the master nodes. The following applications are needed for this:
  # * kubelet: Manages the pods and the containers running on the machine. For the master node this means the control plane components.
  # * kubeadm: For downloading the control plane component images and starting containers from them
  # * kubectl: For managing the cluster
  # * Container technology (docker,podman, CRI-O etc.): To run the containers that make up the control plane

  config.vm.define "K8s-Master" do |master_config|
    # Base box for the vm
    # For reference see: https://yum.oracle.com/boxes
    master_config.vm.box = "oraclelinux/8"
    master_config.vm.box_url = "https://oracle.github.io/vagrant-projects/boxes/oraclelinux/8.json"
    master_config.vm.box_download_checksum = "882ae9f9558532895c606469b7dce9001c140e4e4ebbdb3119b95c1bb5c69389"
    master_config.vm.box_download_checksum_type = "sha256"

    # Setup the internal network
    master_config.vm.hostname = "K8s-Master"
    master_config.vm.network "private_network", ip: "10.0.1.1", virtualbox__intnet: "K8sNetwork"

    # Provider-specific configuration which is in our case virtualbox
    master_config.vm.provider "virtualbox" do |vb|
      # Display the VirtualBox GUI when booting the machine
      # vb.gui = true
  
      # Customize the amount of memory on the VM:
      vb.memory = "4096"
  
      # Set the vm name
      vb.name = "K8s-Master"
    end

    # Provision the master vm using the above shell commands
    master_config.vm.provision "shell" do |s|
      s.path = "setup_master.sh"
    end
  end

  # Create the worker nodes
  # The same applications need to be installed for worker nodes then for master nodes
  # * kubelet: For the communication with master nodes and the management of the pods and containers
  # * kubeadm: To join the node to a cluster
  # * Container technology (docker, podman, CRI-O etc.): To run the containers
  # The only exception is kubectl which is only be needed by master nodes

  config.vm.define "K8s-Worker1" do |worker_config|
    # Base box for the vm
    # For reference see: https://yum.oracle.com/boxes
    worker_config.vm.box = "oraclelinux/8"
    worker_config.vm.box_url = "https://oracle.github.io/vagrant-projects/boxes/oraclelinux/8.json"
    worker_config.vm.box_download_checksum = "882ae9f9558532895c606469b7dce9001c140e4e4ebbdb3119b95c1bb5c69389"
    worker_config.vm.box_download_checksum_type = "sha256"

    # Setup the internal network
    # Specify as internal network with: virtualbox__intnet
    worker_config.vm.hostname = "K8s-Worker1"
    worker_config.vm.network "private_network", ip: "10.0.1.2", virtualbox__intnet: "K8sNetwork"

    # Provider-specific configuration which is in our case virtualbox
    worker_config.vm.provider "virtualbox" do |vb|
      # Display the VirtualBox GUI when booting the machine
      # vb.gui = true

      # Customize the amount of memory on the VM:
      vb.memory = "2048"

      # Set the vm name
      vb.name = "K8s-Worker1"
    end

    # Provision the vm using the above shell commands
    worker_config.vm.provision "shell" do |s|
      s.path = "setup_worker.sh"
    end
  end
end
