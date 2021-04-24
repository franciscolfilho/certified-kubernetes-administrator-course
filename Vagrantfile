# -*- mode: ruby -*-
# vi:set ft=ruby sw=2 ts=2 sts=2:

# Define the number of master and worker nodes
# If this number is changed, remember to update setup-hosts.sh script with the new hosts IP details in /etc/hosts of each VM.

## Para poupar memória
NUM_MASTER_NODE = 1
#NUM_MASTER_NODE = 3
#
NUM_WORKER_NODE = 4
#NUM_WORKER_NODE = 0


IP_NW = "192.168.56."
MASTER_IP_START = 10
NODE_IP_START = 20
LB_IP_START = 30
ROUTER_IP_INT_START = 40
ROUTER_IP_EXT_START = 41

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  # config.vm.box = "base"
  config.vm.box = "ubuntu/bionic64"
  #config.vm.box = "ubuntu/focal64"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  config.vm.box_check_update = false

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # 1) vagrant up
  # 2) ENV='kubeconfig' vagrant up --provision
  # 3) ENV='config' vagrant up --provision
  # 4) ENV='routers' vagrant up


  option=ENV['ENV']

  ## Checa se variável ambiente é null (nil)
  if !option
    ##--- APIServer LoadBalancer deve ser instalado antes dos nodes master ---##
    # Provision Load Balancer Node
    config.vm.define "loadbalancer" do |node|
      node.vm.provider "virtualbox" do |vb|
	  vb.name = "kubernetes-ha-lb"
	  vb.memory = 512
	  vb.cpus = 1
      end
      node.vm.hostname = "loadbalancer"
      node.vm.network :private_network, ip: IP_NW + "#{LB_IP_START}"

      node.vm.provision "setup-hosts", :type => "shell", :path => "ubuntu/vagrant/setup-hosts.sh" do |s|
	s.args = ["enp0s8"]
      end

      node.vm.provision "setup-dns", type: "shell", :path => "ubuntu/update-dns.sh"
      node.vm.provision "fix-timezone", :type => "shell", :path => "ubuntu/fix-timezone.sh"
      node.vm.provision "install-haproxy-api-loadbalancer", :type => "shell", :path => "ubuntu/install-haproxy-api-loadbalancer.sh"

      node.vm.provision "install-kubernetes-common-tools.sh", :type => "shell", privileged: false, :path => "ubuntu/install-kubernetes-common-tools.sh"
    end #config

   
    # Instalando master nodes - procedimentos comuns
    (1..NUM_MASTER_NODE).each do |i|
	config.vm.define "master-#{i}" do |node|
	  # Name shown in the GUI
	  node.vm.provider "virtualbox" do |vb|
	      vb.name = "kubernetes-ha-master-#{i}"
	      vb.memory = 1024
	      vb.cpus = 2
	  end
	  node.vm.hostname = "master-#{i}"
	  node.vm.network :private_network, ip: IP_NW + "#{MASTER_IP_START + i}"

	  node.vm.provision "setup-hosts", :type => "shell", :path => "ubuntu/vagrant/setup-hosts.sh" do |s|
	    s.args = ["enp0s8"]
	  end

	  node.vm.provision "setup-dns", type: "shell", :path => "ubuntu/update-dns.sh"
	  node.vm.provision "install-docker", type: "shell", :path => "ubuntu/install-docker-2.sh"
	  node.vm.provision "setup-cgroup-docker-driver", type: "shell", :path => "ubuntu/setup-cgroup-docker-driver.sh"
	  node.vm.provision "allow-bridge-nf-traffic", :type => "shell", :path => "ubuntu/allow-bridge-nf-traffic.sh"
	  node.vm.provision "fix-timezone", :type => "shell", :path => "ubuntu/fix-timezone.sh"

	  node.vm.provision "install-kubernetes-common-tools.sh", :type => "shell", privileged: false, :path => "ubuntu/install-kubernetes-common-tools.sh"
       end #config
    end # do

    ## Instala o control-plane na master-1
    ## Precisa que o loadbalancer do apiserver já esteja em execução
    config.vm.define "master-1" do |node| 
       node.vm.provision "install-control-plane-master-1", :type => "shell", privileged: false, :path => "ubuntu/install-control-plane-master-1.sh"
       node.vm.provision "install-pod-netword-addon-master-1", :type => "shell", privileged: false, :path => "ubuntu/install-pod-netword-addon.sh"
       node.vm.provision "share-master-kubeconfig", :type => "shell", privileged: false, :path => "ubuntu/share-master-kubeconfig.sh"
    end

    ## Concluindo configuração dos master nodes restantes
    (2..NUM_MASTER_NODE).each do |i|
	config.vm.define "master-#{i}" do |node|
	   node.vm.provision "join-master-node", :type => "shell", :path => "control_plane_join_command.sh"
	end
    end
   
    # Provision Worker Nodes
    (1..NUM_WORKER_NODE).each do |i|
      config.vm.define "worker-#{i}" do |node|
	  node.vm.provider "virtualbox" do |vb|
	      vb.name = "kubernetes-ha-worker-#{i}"
	      vb.memory = 1024
	      vb.cpus = 1
	  end
	  node.vm.hostname = "worker-#{i}"
	  node.vm.network :private_network, ip: IP_NW + "#{NODE_IP_START + i}"

	  node.vm.provision "setup-hosts", :type => "shell", :path => "ubuntu/vagrant/setup-hosts.sh" do |s|
	    s.args = ["enp0s8"]
	  end

	  node.vm.provision "setup-dns", type: "shell", :path => "ubuntu/update-dns.sh"
	  node.vm.provision "install-docker", type: "shell", :path => "ubuntu/install-docker-2.sh"
	  node.vm.provision "setup-cgroup-docker-driver", type: "shell", :path => "ubuntu/setup-cgroup-docker-driver.sh"
	  node.vm.provision "allow-bridge-nf-traffic", :type => "shell", :path => "ubuntu/allow-bridge-nf-traffic.sh"
	  node.vm.provision "fix-timezone", :type => "shell", :path => "ubuntu/fix-timezone.sh"

	  node.vm.provision "install-kubernetes-common-tools.sh", :type => "shell", privileged: false, :path => "ubuntu/install-kubernetes-common-tools.sh"
	  node.vm.provision "join-worker-node", :type => "shell", :path => "worker_node_join_command.sh"
      end #config
    end #do
  end #if

  if ENV['ENV'] == 'kubeconfig' 
    config.vm.define "loadbalancer" do |node| 
       node.vm.provision "copy-master-kubeconfig", :type => "shell", privileged: false, :path => "ubuntu/copy-master-kubeconfig.sh"
    end
  end # if

  if ENV['ENV'] == 'config' 
    config.vm.define "loadbalancer" do |node| 
       node.vm.provision "set-labels-on-nodes", :type => "shell", privileged: false, :path => "ubuntu/set-labels-on-nodes.sh"
       node.vm.provision "install-ingress-controllers", :type => "shell", privileged: false, :path => "ubuntu/install-ingress-controllers.sh"
    end
  end # if


  if ENV['ENV'] == 'routers' 
    # Provision Internal HAProxy Router 
    config.vm.define "haproxy-router-int" do |node|
      node.vm.provider "virtualbox" do |vb|
	  vb.name = "haproxy-router-int"
	  vb.memory = 512
	  vb.cpus = 1
      end
      node.vm.hostname = "haproxy-router-int"

      node.vm.network :private_network, ip: IP_NW + "#{ROUTER_IP_INT_START}"

      node.vm.provision "setup-dns", type: "shell", :path => "ubuntu/update-dns.sh"
      node.vm.provision "fix-timezone", :type => "shell", :path => "ubuntu/fix-timezone.sh"

      node.vm.provision "setup-hosts", :type => "shell", :path => "ubuntu/vagrant/setup-hosts.sh" do |s|
	s.args = ["enp0s8"]
      end

      ## Essa ordem é importante, já que o script que configura o haproxy usa o kubectl
      node.vm.provision "install-kubernetes-common-tools.sh", :type => "shell", privileged: false, :path => "ubuntu/install-kubernetes-common-tools.sh"
      node.vm.provision "copy-master-kubeconfig", :type => "shell", privileged: false, :path => "ubuntu/copy-master-kubeconfig.sh"
      node.vm.provision "install-haproxy", :type => "shell", privileged: false, :path => "ubuntu/install-haproxy-int.sh"
      #
    end #config

    # Provision External HAProxy Router 
    config.vm.define "haproxy-router-ext" do |node|
      node.vm.provider "virtualbox" do |vb|
	  vb.name = "haproxy-router-ext"
	  vb.memory = 512
	  vb.cpus = 1
      end
      node.vm.hostname = "haproxy-router-ext"

      node.vm.network :private_network, ip: IP_NW + "#{ROUTER_IP_EXT_START}"

      node.vm.provision "setup-dns", type: "shell", :path => "ubuntu/update-dns.sh"
      node.vm.provision "fix-timezone", :type => "shell", :path => "ubuntu/fix-timezone.sh"

      node.vm.provision "setup-hosts", :type => "shell", :path => "ubuntu/vagrant/setup-hosts.sh" do |s|
	s.args = ["enp0s8"]
      end
   
      ## Essa ordem é importante, já que o script que configura o haproxy usa o kubectl
      node.vm.provision "install-kubernetes-common-tools.sh", :type => "shell", privileged: false, :path => "ubuntu/install-kubernetes-common-tools.sh"
      node.vm.provision "copy-master-kubeconfig", :type => "shell", privileged: false, :path => "ubuntu/copy-master-kubeconfig.sh"
      node.vm.provision "install-haproxy", :type => "shell", privileged: false, :path => "ubuntu/install-haproxy-ext.sh"
      #
    end #config
  end #if  

end
