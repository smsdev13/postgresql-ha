Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.boot_timeout = 6000

  nodes = {
    "ansible" => {
      ip: "10.10.10.5",
      memory: 1024,
      cpus: 1
    },
    "db1" => {
      ip: "10.10.10.11",
      memory: 2048,
      cpus: 1
    },
    "db2" => {
      ip: "10.10.10.12",
      memory: 2048,
      cpus: 1
    },
    "db3" => {
      ip: "10.10.10.13",
      memory: 2048,
      cpus: 1
    },
    "lb1" => {
      ip: "10.10.10.21",
      memory: 500,
      cpus: 1
    },
    "lb2" => {
      ip: "10.10.10.22",
      memory: 500,
      cpus: 1
    },
    "backup1" => {
      ip: "10.10.10.31",
      memory: 500,
      cpus: 1
    }
  }

  nodes.each do |name, cfg|
    config.vm.define name do |node|
      node.vm.hostname = name
      node.vm.network "private_network", ip: cfg[:ip]

      node.vm.provider "virtualbox" do |vb|
        vb.memory = cfg[:memory]
        vb.cpus = cfg[:cpus]
        vb.name = "postgres-ha-#{name}"
      end

      node.vm.provision "shell", inline: <<-SHELL
        apt-get update -y
        apt-get install -y python3 sudo curl vim
      SHELL
    end
  end
end