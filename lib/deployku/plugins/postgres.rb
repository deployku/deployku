require 'fileutils'
require 'securerandom'

module Deployku
  class PostgresPlugin < Deployku::Plugin
    include Deployku::Configurable
    include Deployku::Containerable

    def initialize
      @config = {
        'from' => 'postgres',
        'env' => {}
      }
    end

    describe :create, '<NAME>', 'creates new PostgreSQL instance', acl_sys: :admin
    def create(name)
      app_dir = dir(name)
      unless Dir.exists?(app_dir)
        FileUtils.mkdir_p(app_dir)
      end
      app_dir
    end

    describe :delete, '<NAME>', 'deletes an existing PostgreSQL instance', acl_sys: :admin
    def delete(name)
      app_dir = dir(name)
      if Dir.exists?(app_dir)
        puts "removing: #{app_dir}"
        FileUtils.rm_rf(app_dir)
      end
    end

    describe :list, '', 'lists available PostgreSQL instances', acl_sys: :admin
    def list
      Dir.glob(File.join(Deployku::Config.home, '.postgres', '*')) do |path|
        puts File.basename(path) if File.directory?(path)
      end
    end

    describe :dumpall, '<NAME>', 'calls pg_dumpall on specified PostgreSQL instance', acl_sys: :admin
    def dumpall(name)
      config_load(name)
      cid = get_container_id(name)
      unless Deployku::Engine.running?(cid)
        puts "Database instance '#{name}' is not running."
        exit 1
      end
      ip = Deployku::Engine.ip(cid)
      system "PGPASSWORD=\"#{@config['env']['POSTGRES_PASSWORD']}\" pg_dumpall -h #{ip} -U postgres"
    end

    describe 'db:dump', '<NAME> <DB_NAME>', 'calls pg_dump on specified database', acl_sys: :admin
    def db_dump(name, db_name)
      config_load(name)
      cid = get_container_id(name)
      unless Deployku::Engine.running?(cid)
        puts "Database instance '#{name}' is not running."
        exit 1
      end
      ip = Deployku::Engine.ip(cid)
      db = Deployku.sanitize_app_name(db_name)
      system "PGPASSWORD=\"#{@config['env']['POSTGRES_PASSWORD']}\" pg_dump -h #{ip} -d #{db} -U postgres"
    end

    describe 'db:create', '<NAME> <DB_NAME>', 'create a database in postgres instance', acl_sys: :admin
    def db_create(name, db_name)
      config_load(name)
      cid = get_container_id(name)
      unless Deployku::Engine.running?(cid)
        puts "Database instance '#{name}' is not running."
        exit 1
      end
      ip = Deployku::Engine.ip(cid)
      db = Deployku.sanitize_app_name(db_name)
      system "echo 'CREATE DATABASE #{db};' | PGPASSWORD=\"#{@config['env']['POSTGRES_PASSWORD']}\" psql -h #{ip} -U postgres"
      #system "echo \"#{@config['env']['POSTGRES_PASSWORD']}\n\" 'CREATE DATABASE #{db};' | psql -h #{ip} -U postgres"
    end

    describe 'db:drop', '<NAME> <DB_NAME>', 'destroy a database in postgres instance', acl_sys: :admin
    def db_drop(name, db_name)
      config_load(name)
      cid = get_container_id(name)
      unless Deployku::Engine.running?(cid)
        puts "Database instance '#{name}' is not running."
        exit 1
      end
      ip = Deployku::Engine.ip(cid)
      db = Deployku.sanitize_app_name(db_name)
      #system "echo \"#{@config['env']['POSTGRES_PASSWORD']}\n\" 'DROP DATABASE #{db};' | psql -h #{ip} -U postgres"
      system "echo 'DROP DATABASE #{db};' | PGPASSWORD=\"#{@config['env']['POSTGRES_PASSWORD']}\" psql -h #{ip} -U postgres"
    end

    describe 'db:link', '<NAME> <DB_NAME> <APP>', 'connect appliaction with database', acl_sys: :admin
    def db_link(name, db_name, app_name)
      config_load(name)
      db_id = get_container_id(name)
      ip = Deployku::Engine.ip(db_id)
      db = Deployku.sanitize_app_name(db_name)
      user_name = 'user_' + SecureRandom.uuid.gsub('-','')
      user_passwd = SecureRandom.uuid
      database_url = "postgres://#{user_name}:#{user_passwd}@#{container_name(name)}/#{db}"
      system "echo \"CREATE USER #{user_name} WITH PASSWORD '#{user_passwd}';\" | PGPASSWORD=\"#{@config['env']['POSTGRES_PASSWORD']}\" psql -h #{ip} -U postgres"
      system "echo 'GRANT ALL ON DATABASE #{db} TO #{user_name};' | PGPASSWORD=\"#{@config['env']['POSTGRES_PASSWORD']}\" psql -h #{ip} -U postgres"
      if $?.exitstatus == 0
        Deployku::AppPlugin.run('config:set', [app_name, 'DATABASE_URL', database_url])
        Deployku::AppPlugin.run(:link, [app_name, container_name(name)])
      else
        puts "Unable to create user in database."
        exit 1
      end
    end

    describe 'db:connect', '<NAME> <DB_NAME>', 'connect to database and enter prompt', acl_sys: :admin
    def db_connect(name, db_name)
      config_load(name)
      db_id = get_container_id(name)
      dbname = Deployku.sanitize_app_name(db_name)
      ip = Deployku::Engine.ip(db_id)
      system "PGPASSWORD=\"#{@config['env']['POSTGRES_PASSWORD']}\" psql -h #{ip} -U postgres #{dbname}"
    end

    describe 'db:connect:app', '<NAME> <APP_NAME>', 'connect to database as an app user and enter prompt', acl_app: { 1 => :admin }
    def db_connect_app(name, app_name)
      config_load(name)
      db_id = get_container_id(name)
      ip = Deployku::Engine.ip(db_id)
      database_url = Deployku::AppPlugin.instance.config_get(app_name, 'DATABASE_URL')
      if database_url =~ /postgres:\/\/([^:]+):([^@]+)@[^\/]+\/([^\/]+)/
        user_name, password, dbname = $1, $2, $3
        system "PGPASSWORD=\"#{password}\" psql -h #{ip} -U #{user_name} #{dbname}"
      else
        puts "Wrong DATABASE_URL: #{database_url}"
      end
    end

    # methods from containerable
    describe :start, '<NAME>', 'starts container', acl_sys: :admin
    def start(app_name)
      config_load(app_name)
      unless @config['volumes']
        @config['volumes'] = {
          File.join(dir(app_name), 'data') => '/postgresql/'
        }
      end
      @config['env']['PGDATA'] = '/postgresql/' unless @config['env']['PGDATA']
      @config['env']['POSTGRES_PASSWORD'] = SecureRandom.uuid unless @config['env']['POSTGRES_PASSWORD']
      @config['env']['PGPASSWORD'] = @config['env']['POSTGRES_PASSWORD']
      config_save(app_name)

      Deployku::Config.merge!(@config)
      app_hash = Deployku::Engine.start(@config['from'], dir(app_name), container_name(app_name))
      exit 1 if $?.nil? || $?.exitstatus != 0
      set_container_id(app_name, container_name(app_name))
      puts "Container #{app_hash} started."
    end

    describe :run, '<NAME> <CMD>', 'starts a cmd in postgresql environment', acl_sys: :admin
    def run(app_name, *cmd)
      config_load(app_name)
      Deployku::Config.merge!(@config)
      Deployku::Engine.run(@config['from'], dir(app_name), *cmd)
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
      File.join(Deployku::Config.home, '.postgres', Deployku.sanitize_app_name(name))
    end

    def container_name(app_name)
      "deployku-postgres-#{Deployku.sanitize_app_name(app_name)}"
    end
  end
end
