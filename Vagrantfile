# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/wily64"
  config.vm.network "private_network", ip: "10.0.8.8"
  config.vm.network "forwarded_port", guest: 3000, host: 3000

  #TODO configure NFS

  config.vm.hostname = "timeoverflow-dev"
  config.ssh.forward_agent = true
  config.ssh.port = 2222

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
    vb.cpus = 2
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end

 if ENV["SET_UBUNTU_PASSWORD"] == "1"
    config.ssh.username = "vagrant"
    config.ssh.password = "vagrant"
    config.vm.provision "shell", inline: "echo ubuntu:ubuntu | sudo chpasswd"
  else
    config.ssh.username = "ubuntu"
    config.ssh.password = "ubuntu"
  end
end
