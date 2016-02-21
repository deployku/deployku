require 'fileutils'
require 'yaml'

module Deployku::Configurable
  attr_reader :config

  def config_show(app_name)
    app_config_path = config_path(app_name)
    puts File.read(app_config_path) if File.exists?(app_config_path)
  end

  def config_set(app_name, var, value)
    config_load(app_name)
    @config['env'][var.to_s] = value
    config_save(app_name)
  end

  def config_unset(app_name, var)
    config_load(app_name)
    @config['env'].delete(var.to_s)
    config_save(app_name)
  end

  def config_get(app_name, var)
    config_load(app_name)
    @config['env'][var.to_s]
  end

  def config_set_from(app_name, value)
    config_load(app_name)
    @config['from'] = value
    config_save(app_name)
  end

  def config_unset_from(app_name)
    config_load(app_name)
    @config.delete('from')
    config_save(app_name)
  end

  def config_set_engine(app_name, value)
    config_load(app_name)
    @config['engine'] = value
    config_save(app_name)
  end

  def config_unset_engine(app_name)
    config_load(app_name)
    @config.delete('engine')
    config_save(app_name)
  end

  def config_set_port(app_name, value)
    config_load(app_name)
    @config['port'] = value
    config_save(app_name)
  end

  def config_unset_port(app_name)
    config_load(app_name)
    @config.delete('port')
    config_save(app_name)
  end

  def config_load(app_name)
    app_config_path = config_path(app_name)
    @config.merge!(YAML.load_file(app_config_path)) if File.exists?(app_config_path)
  end

  def config_save(app_name)
    app_config_path = config_path(app_name)
    File.open(app_config_path, 'w') do |f|
      f << @config.to_yaml
    end
  end

  def config_path(app_name)
    File.join(dir(app_name), 'DEPLOYKU_CONFIG.yml')
  end
end