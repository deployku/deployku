module Deployku
  class AppPlugin < Deployku::Plugin
    include Deployku::Configurable
    include Deployku::Containerable

    def initialize
      @config = {
        'env' => {},
        'links' => []
      }
    end

    describe :create, '<APP>', 'creates new application', acl_sys: :admin
    def create(app_name)
      app_dir = dir(app_name)
      unless Dir.exists?(app_dir)
        Dir.mkdir(app_dir)
        system "git init -q --bare '#{app_dir}'"
      end
      app_dir
    end

    describe :delete, '<APP>', 'deletes an existing application', acl_sys: :admin
    def delete(app_name)
      app_dir = dir(app_name)
      if Dir.exists?(app_dir)
        FileUtils.rm_rf(app_dir)
      end
    end

    describe :list, '', 'list available applications', acl_sys: :admin
    def list
      apps = get_app_list
      apps.each { |app| puts app }
    end

    describe :status, '<APP>', 'show container status', acl_app: { 0 => :commit }
    describe :start, '<APP>', 'starts container', acl_app: { 0 => :admin }
    def start(app_name)
      super(app_name)
      result = true
      plugins = Deployku::Plugin.filter_plugins(:after_start)
      plugins.each do |plug|
        result = result && plug.after_start(app_name)
      end
      result
    end
    describe :run, '<APP> <CMD>', 'starts a cmd in application environment', acl_app: { 0 => :admin }
    describe :stop, '<APP>', 'stops running container', acl_app: { 0 => :admin }
    describe :restart, '<APP>', 'restarts container', acl_app: { 0 => :admin }
    describe :logs, '<APP>', 'show app logs', acl_app: { 0 => :admin }

    describe :rebuild, '<APP> [REV] [NOCACHE]', 'rebuild container. REV can be eg. master NOCACHE can be true', acl_app: { 0 => :admin }
    def rebuild(app_name, new_rev=nil, nocache=false)
      app_dir = dir(app_name)
      app_name = File.basename(app_dir)
      Dir.mktmpdir('deployku_') do |tmp_dir|
        tmp_app_dir = File.join(tmp_dir, 'app')
        Dir.mkdir(tmp_app_dir)
        system "git clone -q '#{app_dir}' '#{tmp_app_dir}'"
        Dir.chdir(tmp_app_dir)
        system "unset GIT_DIR GIT_WORK_TREE && git checkout #{new_rev}" if new_rev
        system 'unset GIT_DIR GIT_WORK_TREE && git submodule update --init --recursive'
        Dir.chdir(tmp_dir)

        plugins = Deployku::Plugin.filter_plugins(:detect)
        plugin = nil
        plugins.each do |plug|
          if plug.detect(tmp_app_dir)
            plugin = plug
            break
          end
        end

        deployku_config_path = File.join(tmp_app_dir, 'deployku.yml')
        Deployku::Config.load(deployku_config_path)
        Deployku::Config.load(config_path(app_name))
        config_load(app_name)

        unless plugin
          puts "Unsupported application type"
          exit 1
        else
          if plugin.respond_to?(:port) && !@config['port']
            config_set_port(app_name, plugin.port)
            Deployku::Config.merge!({ port: plugin.port })
          end

          plugin.build_start_script(tmp_dir)
          case Deployku::Config.engine
            when 'docker'
              plugin.build_dockerfile(tmp_dir)
            when 'lxc'
              puts 'not implemented'
          end
        end

        if Deployku::Engine.rebuild(app_name, tmp_dir, nocache == 'true')
          plugin.volumes.each do |volume|
            config_add_volume(app_name, volume)
          end if plugin.respond_to?(:volumes)

          restart(app_name)
        else
          exit 1
        end
      end
    end

    describe 'config:show', '<APP>', 'shows app configuration', acl_app: { 0 => :admin }
    describe 'config:set', '<APP> <ENV_VARIABLE> <VALUE>', 'sets environment variable', acl_app: { 0 => :admin }
    describe 'config:unset', '<APP> <ENV_VARIABLE>', 'unsets environment variable', acl_app: { 0 => :admin }
    describe 'config:set_from', '<APP> <VALUE>', 'sets base image name for container', acl_app: { 0 => :admin }
    describe 'config:unset_from', '<APP>', 'sets base image to default', acl_app: { 0 => :admin }
    describe 'config:set_engine', '<APP> <ENGINE>', 'sets container engine (docker, lxc)', acl_app: { 0 => :admin }
    describe 'config:unset_engine', '<APP>', 'sets engine to default', acl_app: { 0 => :admin }
    describe 'config:set_port', '<APP> <PORT>', 'sets port on which will application listen', acl_app: { 0 => :admin }
    describe 'config:unset_port', '<APP>', 'remove port setting', acl_app: { 0 => :admin }

    describe 'config:add_domain', '<APP> <DOMAIN>', 'bind domain with application', acl_app: { 0 => :admin }
    def config_add_domain(app_name, domain)
      config_load(app_name)
      @config['domains'] ||= []
      @config['domains'] << domain
      config_save(app_name)
    end

    describe 'config:rm_domain', '<APP> <DOMAIN>', 'removes domain from the list', acl_app: { 0 => :admin }
    def config_rm_domain(app_name, package)
      config_load(app_name)
      if @config['domains']
        @config['domains'].delete(package)
        config_save(app_name)
      end
    end

    describe 'config:add_package', '<APP> <PACKAGE>', 'will install additional package when rebuild', acl_app: { 0 => :admin }
    def config_add_package(app_name, package)
      config_load(app_name)
      @config['packages'] ||= []
      @config['packages'] << package
      config_save(app_name)
    end

    describe 'config:rm_package', '<APP> <PACKAGE>', 'removes package from the list', acl_app: { 0 => :admin }
    def config_rm_package(app_name, package)
      config_load(app_name)
      if @config['packages']
        @config['packages'].delete(package)
        config_save(app_name)
      end
    end

    describe 'config:add_volume', '<APP> <PATH>', 'mounts container path to app directory', acl_app: { 0 => :admin }
    def config_add_volume(app_name, path)
      config_load(app_name)
      vpath = volume_path(app_name, path)
      unless Dir.exists?(vpath)
        FileUtils.mkpath(vpath)
      end
      @config['volumes'] ||= {}
      @config['volumes'][vpath] = path unless @config['volumes'][vpath]
      config_save(app_name)
    end

    describe 'config:rm_volume', '<APP> <PATH>', 'removes volume', acl_app: { 0 => :admin }
    def config_rm_volume(app_name, path)
      config_load(app_name)
      vpath = volume_path(app_name, path)
      if @config['volumes']
        @config['volumes'].delete(vpath)
        config_save(app_name)
      end
    end

    describe 'link', '<APP> <LINK>', 'adds link', acl_sys: :admin
    def link(app_name, link)
      config_load(app_name)
      @config['links'] ||= []
      @config['links'] << link
      config_save(app_name)
    end

    describe 'unlink', '<APP> <LINK>', 'removes link', acl_sys: :admin
    def unlink(app_name, link)
      config_load(app_name)
      if @config['links']
        @config['links'].delete(link)
        config_save(app_name)
      end
    end

    def volume_path(app_name, path)
      volume = Deployku.sanitize_app_name(path)
      File.join(dir(app_name), 'DEPLOYKU_VOLUMES', volume)
    end

    def dir(app_name)
      File.join(Deployku::Config.home, Deployku.sanitize_app_name(app_name))
    end

    def get_app_list
      apps = []
      Dir.glob(File.join(Deployku::Config.home, '*')) do |path|
        apps << File.basename(path) if File.directory?(path)
      end
      apps
    end

  end
end