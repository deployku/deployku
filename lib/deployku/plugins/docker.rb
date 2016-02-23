require 'json'

module Deployku
  class DockerEngine < Deployku::Plugin
    include Deployku::Engine

    def start(app_name, app_dir=nil, name=nil)
      args = build_args(app_name, app_dir, name)
      hash = `docker run -d -P #{args.join(' ')} #{app_name}:latest`.chomp
      if $?.exitstatus != 0 && name
        hash = `docker start '#{name}'`.chomp
      end
      hash
    end

    def run(app_name, app_dir, *cmd)
      args = build_args(app_name, app_dir)
      system "docker run -t -i --rm --entrypoint=/bin/bash #{args.join(' ')} #{app_name}:latest -c \"#{cmd.join(' ')}\""
    end

    def stop(app_hash)
      system "docker stop #{app_hash}"
    end

    def logs(app_hash)
      system "docker logs #{app_hash}"
    end

    def rebuild(app_name, dir, nocache)
      nocache_str = nocache ? '--no-cache' : ''
      system "docker build #{nocache_str} -t #{app_name}:latest #{dir}"
    end

    def running?(app_hash)
      stat = JSON.parse(`docker inspect #{app_hash}`).first
      return stat['State']['Running'] if stat && stat['State']
      nil
    end

    def ip(app_hash)
      stat = JSON.parse(`docker inspect #{app_hash}`).first
      return stat['NetworkSettings']['IPAddress'] if stat && stat['NetworkSettings']
      nil
    end

    protected

    def build_args(app_name, app_dir, name=nil)
      args = []
      if app_dir && Deployku::Config.env
        env_path = File.join(app_dir, 'DEPLOYKU_ENV')
        File.open(env_path, 'w') do |f|
          Deployku::Config.env.each do |key, value|
            f << "#{key}=#{value}\n"
          end
        end
        args << "--env-file='#{env_path}'"
      end

      if app_dir && Deployku::Config.volumes && Deployku::Config.volumes.count > 0
        Deployku::Config.volumes.each do |src, dst|
          args << "--volume='#{src}:#{dst}'"
        end
      end

      if app_dir && Deployku::Config.links && Deployku::Config.links.count > 0
        Deployku::Config.links.each do |link|
          args << "--link='#{link}'"
        end
      end

      if name
        args << "--name='#{name}'"
      end
      args
    end
  end
end