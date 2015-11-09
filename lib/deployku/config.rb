require 'yaml'

module Deployku
  class Config
    # TODO: read variables from config file

    @config = nil

    HOME = File::expand_path('~deployku')
    FROM = 'pejuko/rvm-base'
    PACKAGES = ['git']
    DEFAULT_ENGINE = 'docker'
    DEFAULT_PORT = 80

    class << self
      def home
        HOME
      end

      def engine
        (@config && @config['engine']) ? @config['engine'] : DEFAULT_ENGINE
      end

      def from
        (@config && @config['from']) ? @config['from'] : FROM
      end

      def packages
        (@config && @config['packages']) ? @config['packages'] : PACKAGES
      end

      def port
        (@config && @config['port']) ? @config['port'] : DEFAULT_PORT
      end

      def method_missing(method, *args)
        return nil unless @config
        return @config[method.to_s]
      end

      def merge!(opts)
        unless @config
          @config = {
            'from' => FROM,
            'packages' => PACKAGES,
            'engine' => DEFAULT_ENGINE
          }
        end
        deep_merge!(@config, opts)
      end

      def deep_merge!(hash1, hash2)
        hash2.each do |key, value|
          k = key.to_s
          unless hash1[k]
            hash1[k] = value
          else
            if hash1[k].kind_of?(Hash)
              deep_merge!(hash1[k], value)
            elsif hash1[k].kind_of?(Array)
              hash1[k] = hash1[k] + value
            else
              hash1[k] = value
            end
          end
        end
      end

      def set_opts(key, opts)
        @config[key.to_s] = opts[key.to_s] if opts[key.to_s]
      end

      def load(path=File.join(HOME, '.deployku.yaml'))
        if File.exists?(path)
          deployku_config = YAML.load_file(path)
          Deployku::Config.merge!(deployku_config)
          true
        else
          false
        end
      end

      def save(path=File.join(HOME, '.deployku.yaml'))
        if @config
          File.open(path, 'w') do |f|
            f << @config.to_yaml
          end
        end
      end
    end
  end
end