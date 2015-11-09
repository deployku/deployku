require 'fileutils'

module Deployku
  class RailsPlugin < Deployku::Plugin
    PACKAGES = ['nodejs']

    def volumes
      ['/app/public/']
    end

    def port
      3000
    end

    def build_start_script(path)
      app_path = File.join(path, 'app')
      start_path = File.join(path, 'start')
      custom_start_path = File.join(app_path, 'start')
      if File.exists?(custom_start_path)
        FileUtils.cp(custom_start_path, start_path)
      else
        File.open(start_path, 'w') do |f|
          f << <<EOF
#!/usr/bin/env bash
source /usr/local/rvm/scripts/rvm
cd app
export RAILS_ENV=production
bundle exec rake db:migrate RAILS_ENV=production
bundle exec rake assets:precompile RAILS_ENV=production

bundle exec rails s -p #{Deployku::Config.port} -b 0.0.0.0 -e production
EOF
        end
      end
      File.chmod(0755, start_path)
    end

    def build_dockerfile(path)
      app_path = File.join(path, 'app')
      ruby_version = detect_ruby_version(app_path)
      dockerfile_path = File.join(path, 'Dockerfile')
      # TODO: process Dockerfile with erubis
      custom_docker_file = File.join(app_path, 'Dockerfile')
      if File.exists?(custom_docker_file)
        FileUtils.cp(custom_docker_file, dockerfile_path)
      else
        File.open(dockerfile_path, 'w') do |f|
          f << <<EOF
FROM #{Deployku::Config.from}

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update

RUN /bin/bash -l -c 'rvm install #{ruby_version} && rvm use #{ruby_version} --default'
RUN /bin/bash -l -c 'rvm rubygems current'
RUN /bin/bash -l -c 'gem install bundler'

RUN /bin/bash -l -c 'rvm cleanup all'

RUN apt-get install -y #{packages.join(' ')}

RUN apt-get -y autoclean
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE #{Deployku::Config.port}
CMD []
ENTRYPOINT ["/start"]

ADD start /start

ADD app /app
RUN /bin/bash -l -c 'cd app && RAILS_ENV=production bundle install --without development test'
EOF
        end
      end
    end

    def detect(path)
      gem_file_path = File.join(path, 'Gemfile')
      if File.exists?(gem_file_path)
        if File.read(gem_file_path) =~ %r{^\s*gem\s+['"](rails)['"]}m
          return true
        end
      end
      false
    end

    def detect_ruby_version(path)
      gem_file_path = File.join(path, 'Gemfile')
      if File.exists?(gem_file_path)
        ruby_version = File.read(gem_file_path).gsub(%r{.*ruby\s+['"]([^'"]+)['"].*}m, '\1')
      end
      if not ruby_version || ruby_version == ''
        ruby_version = '2.1.7'
      end
      ruby_version
    end
  end
end
