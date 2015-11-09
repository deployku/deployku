require 'securerandom'
require 'net/http'

module Deployku
  class NginxPlugin < Deployku::Plugin
    describe :enable, '<APP>', 'enable nginx for application', acl_app: { 0 => :admin }
    def enable(app_name)
      app_plug = Deployku::AppPlugin.new
      app_plug.config_load(app_name)
      app_plug.config['nginx'] = {} unless app_plug.config['nginx']
      app_plug.config['nginx']['enabled'] = true
      app_plug.config['nginx']['port'] = 80 unless app_plug.config['nginx']['port']
      app_plug.config['nginx']['wait'] = 300 unless app_plug.config['nginx']['wait']
      app_plug.config['nginx']['public_volume'] = '/app/public/' unless app_plug.config['nginx']['public_volume']
      app_plug.config_save(app_name)
    end

    describe :disable, '<APP>', 'disable nginx for application', acl_app: { 0 => :admin }
    def disable(app_name)
      app_plug = Deployku::AppPlugin.new
      app_plug.config_load(app_name)
      if app_plug.config['nginx']
        app_plug.config['nginx']['enabled'] = false
        app_plug.config_save(app_name)
      end
    end

    describe 'config:set', '<APP> <NAME> <VALUE>', 'sets nginx parametr', acl_app: { 0 => :admin }
    def config_set(app_name, name, value)
      app_plug = Deployku::AppPlugin.new
      app_plug.config_load(app_name)
      app_plug.config['nginx'] = {} unless app_plug.config['nginx']
      app_plug.config['nginx'][name] = value
      app_plug.config_save(app_name)
    end

    describe 'config:unset', '<APP> <NAME>', 'unsets nginx parametr', acl_app: { 0 => :admin }
    def config_unset(app_name, name, value)
      app_plug = Deployku::AppPlugin.new
      app_plug.config_load(app_name)
      if app_plug.config['nginx']
        app_plug.config['nginx'].delete(name)
        app_plug.config_save(app_name)
      end
    end

    describe 'config:build', '<APP>', 'rebuild config for an application', acl_app: { 0 => :admin }
    def config_build(app_name)
      app_plug = Deployku::AppPlugin.new
      app_plug.config_load(app_name)
      cid = app_plug.get_container_id(app_name)
      ip = Deployku::Engine.ip(cid)
      upstream = SecureRandom.uuid.gsub('-', '')
      vpath = app_plug.volume_path(app_name, app_plug.config['nginx']['public_volume'])
      domains = app_plug.config['domains']
      if !domains || domains.empty?
        puts "No domains."
        exit 1
      end
      unless app_plug.config['port']
        puts "No application port."
        exit 1
      end
      File.open(config_path(app_name), 'w') do |f|
        f << <<EOF
upstream #{upstream} {
  server #{ip}:#{app_plug.config['port']};
}

server {
  listen #{app_plug.config['nginx']['port']};
  server_name #{domains.join(' ')};
  root #{vpath};

  gzip on;
  gzip_http_version 1.1;
  gzip_vary on;
  gzip_comp_level 6;
  gzip_proxied any;
  gzip_types text/plain text/html text/css application/json application/javascript application/x-javascript text/javascript text/xml application/xml application/rss+xml application/atom+xml application/rdf+xml;

  location / {
    try_files $uri @#{upstream};
  }

  location @#{upstream} {
    proxy_read_timeout 300;
    proxy_connect_timeout 300;
    proxy_redirect off;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header CLIENT_IP $remote_addr;
    proxy_set_header GEOIP_COUNTRY_CODE $geoip_country_code;
    proxy_pass http://#{upstream};
  }
}
EOF
      end
    end

    def after_start(app_name)
      app_plug = Deployku::AppPlugin.new
      app_plug.config_load(app_name)
      if app_plug.config['nginx'] && app_plug.config['nginx']['enabled']
        config_build(app_name)
        cid = app_plug.get_container_id(app_name)
        ip = Deployku::Engine.ip(cid)
        counter = 0
        $stdout.sync = true
        while counter <= app_plug.config['nginx']['wait'].to_i && !up?(ip, app_plug.config['port'])
          puts "wainting for webserver...#{counter+1}"
          sleep 1
          counter += 1
        end
        if counter > app_plug.config['nginx']['wait'].to_i
          puts "timeouted"
          return false
        else
          system 'sudo nginx -s reload'
        end
      end
      true
    end

    def up?(server, port)
      begin
        http = Net::HTTP.start(server, port, {open_timeout: 5, read_timeout: 5})
        response = http.head("/")
        response.code == "200"
      rescue #Timeout::Error, SocketError
        false
      end
    end

    def config_path(app_name)
      File.join(Deployku::AppPlugin.instance.dir(app_name), 'nginx.conf')
    end
  end
end