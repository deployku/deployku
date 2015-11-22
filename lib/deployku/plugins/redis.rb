require 'fileutils'
require 'securerandom'

module Deployku
  class RedisPlugin < Deployku::Plugin
    include Deployku::Configurable
    include Deployku::Containerable

    def initialize
      @config = {
        'from' => 'redis',
        'env' => {}
      }
    end

    describe :create, '<NAME>', 'creates new Redis instance', acl_sys: :admin
    def create(name)
      app_dir = dir(name)
      unless Dir.exists?(app_dir)
        FileUtils.mkdir_p(app_dir)
      end
      app_dir
    end

    describe :delete, '<NAME>', 'deletes an existing Redis instance', acl_sys: :admin
    def delete(name)
      app_dir = dir(name)
      if Dir.exists?(app_dir)
        FileUtils.rm_rf(app_dir)
      end
    end

    describe :list, '', 'lists available Redis instances', acl_sys: :admin
    def list
      Dir.glob(File.join(Deployku::Config.home, '.redis', '*')) do |path|
        puts File.basename(path) if File.directory?(path)
      end
    end

    describe 'link', '<NAME> <APP>', 'connect appliaction with redis server', acl_sys: :admin
    def link(name, app_name)
      config_load(name)
      redis_id = get_container_id(name)
      redis_url = "redis://#{container_name(name)}:6379/"
      Deployku::AppPlugin.run('config:set', [app_name, 'REDIS_URL', redis_url])
      Deployku::AppPlugin.run(:link, [app_name, container_name(name)])
    end

    # methods from containerable
    describe :start, '<NAME>', 'starts container', acl_sys: :admin
    def start(app_name)
      config_load(app_name)
      unless @config['volumes']
        @config['volumes'] = {
          File.join(dir(app_name), 'redis') => '/data/'
        }
      end
      config_save(app_name)

      Deployku::Config.merge!(@config)
      app_hash = Deployku::Engine.start(@config['from'], dir(app_name), container_name(app_name))
      exit 1 if $?.nil? || $?.exitstatus != 0
      set_container_id(app_name, container_name(app_name))
      puts "Container #{app_hash} started."
    end

    describe :status, '<NAME>', 'show container status', acl_sys: :admin
    describe :stop, '<NAME>', 'stops running container', acl_sys: :admin
    describe :restart, '<NAME>', 'restarts container', acl_sys: :admin
    def restart(app_name)
      # restart can not be done seamlessly because we use named containers
      stop(app_name)
      start(app_name)
    end

    describe :logs, '<NAME>', 'show app logs', acl_sys: :admin

    # methods from configurable
    describe 'config:show', '<NAME>', 'shows instance configuration', acl_sys: :admin
    describe 'config:set', '<NAME> <ENV_VARIABLE> <VALUE>', 'sets environment variable', acl_sys: :admin
    describe 'config:unset', '<NAME> <ENV_VARIABLE>', 'unsets environment variable', acl_sys: :admin
    describe 'config:set_from', '<NAME> <VALUE>', 'sets base image name for container', acl_sys: :admin
    describe 'config:unset_from', '<NAME>', 'sets base image to default', acl_sys: :admin
    describe 'config:set_engine', '<NAME> <ENGINE>', 'sets container engine (docker, lxc)', acl_sys: :admin
    describe 'config:unset_engine', '<NAME>', 'sets engine to default', acl_sys: :admin

    def dir(name)
      File.join(Deployku::Config.home, '.redis', Deployku.sanitize_app_name(name))
    end

    def container_name(app_name)
      "deployku-redis-#{Deployku.sanitize_app_name(app_name)}"
    end
  end
end
