# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'fileutils'
Vagrant.require_version '>= 1.7.0'
VAGRANT_DIR = '/vagrant'
GOCD_HOST_LOCAL = '192.168.33.66'
GOCD_PORTS_LOCAL = { 80 => 8153 , 8154 => 8154}
COREOS_LOCAL_VERSION = '>=877.1.0'
CLOUD_CONFIG_PATH = File.join(File.dirname(__FILE__), 'user-data')
GO_SERVER_IMAGE = 'go_server'
GO_AGENT_IMAGE = 'go_agent'
GO_AGENTS_IMAGES = (1..1).map {|i| GO_AGENT_IMAGE + i.to_s}
Vagrant.configure('2') do |config|
  config.ssh.insert_key = false

  # plugin conflict
  config.vbguest.auto_update = false if Vagrant.has_plugin?('vagrant-vbguest')

  config.vm.define 'local-mcloud-impostor' do |cfg|
    # Provisioning for this box is done by the managed `gocd-local` box
    cfg.vm.provider :virtualbox do |v, override|
      override.vm.network :private_network, ip: GOCD_HOST_LOCAL
      GOCD_PORTS_LOCAL.each do |guest, host|
        override.vm.network 'forwarded_port', guest: guest, host: host
      end
      override.vm.hostname = 'support-dev'
      override.vm.box = 'coreos-alpha'
      override.vm.box_version = COREOS_LOCAL_VERSION
      override.vm.box_url = 'http://alpha.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json'
      v.memory = 3072
      v.check_guest_additions = false
      v.functional_vboxsf     = false
    end
  end

  config.vm.define 'gocd-local' do |cfg|
    your_private_key_which_has_to_be_authorized_in_server_manually = '~/.vagrant.d/insecure_private_key'
    cfg.vm.box = 'tknerr/managed-server-dummy'
    cfg.vm.provider :managed do |managed, override|
      managed.server = GOCD_HOST_LOCAL
      override.ssh.username = 'core'
      override.ssh.private_key_path = your_private_key_which_has_to_be_authorized_in_server_manually
      deploy_cloud_config(override)
    end
    deploy_go_server_and_agent_containers(cfg)
  end

  def deploy_cloud_config(override)
    if File.exist?(CLOUD_CONFIG_PATH)
      override.vm.provision :file, source: CLOUD_CONFIG_PATH, destination: '/tmp/vagrantfile-user-data'
      GO_AGENTS_IMAGES.each do |agent|
        script = <<-eos
        mkdir -p /srv/gocd/go-agents/#{agent}/pipelines
        mkdir -p /srv/gocd/go-agents/#{agent}/logs
        eos
      end

      script = <<-eos
      mkdir -p /var/lib/coreos-vagrant/ && mv -f /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/
      chmod a+rw /var/run/docker.sock
      mkdir -p /srv/gocd/go-server/config
      eos

      override.vm.provision :shell, inline: script, privileged: true
    end
  end
  def deploy_go_server_and_agent_containers(config)
    config.vm.synced_folder '.', '/vagrant', disabled: true
    config.vm.synced_folder './docker/', '/vagrant/docker', type: 'rsync'

    setup_provisioner_for_removing_existing_containers_and_cleanup_images config
    config.vm.provision :docker do |d|
      d.build_image "#{VAGRANT_DIR}/docker/go-server/",
                    args: "-t #{GO_SERVER_IMAGE} -t #{GO_SERVER_IMAGE}:latest"

      d.run GO_SERVER_IMAGE, image: "#{GO_SERVER_IMAGE}:latest", args: '-i -t -p 80:8153 -p 8154:8154 --hostname=go-server -v /srv/gocd/go-server:/godata'

      GO_AGENTS_IMAGES.each do |agent|
        d.build_image "#{VAGRANT_DIR}/docker/go-agent/", args: "-t #{agent} -t #{agent}:latest --build-arg agent=#{agent}"
        go_agent_args = "-d -e GO_SERVER_URL=https://#{GOCD_HOST_LOCAL}:8154/go -e AGENT_AUTO_REGISTER_KEY=123456789abcdef -e SCREEN_WIDTH=1360 -e SCREEN_HEIGHT=1020 -e SCREEN_DEPTH=24"
        d.run agent, image: "#{agent}:latest", args: go_agent_args
      end
    end
  end
  def setup_provisioner_for_removing_existing_containers_and_cleanup_images(config)
    config.vm.provision :shell, inline: 'docker rm -f `docker ps -aq` 2>/dev/null || true'
    config.vm.provision :shell, inline: 'docker rmi `docker images -f dangling=true -q` 2>/dev/null || true'
  end
end
