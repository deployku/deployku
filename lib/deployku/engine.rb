module Deployku::Engine
  class MissingException < Exception
  end

  def self.find_engine(name)
    plugin_name = "Deployku::#{name.capitalize}Engine"
    Deployku::Plugin.plugins.each do |plugin|
      return plugin if plugin.name == plugin_name
    end
    nil
  end

  def self.engines
    engs = []
    Deployku::Plugin.plugins.each do |plugin|
      engs << plugin if plugin.name =~ /^Deployku::.*?Engine$/
    end
    engs
  end

  def self.method_missing(method, *args)
    engine = find_engine(Deployku::Config.engine)
    raise MissingException.new("no engine '#{Deployku::Config.engine}' found") unless engine
    eng = engine.new
    eng.send(method, *args)
  end

  def start(app_name, app_dir)
    puts 'not implemented'
  end

  def run(app_name, app_dir, *cmd)
    puts 'not implemented'
  end

  def stop(app_hash)
    puts 'not implemented'
  end

  def logs(app_hash)
    puts 'not implemented'
  end

  def rebuild(app_name, dir, nocache)
    puts 'not implemented'
  end

  def running?(app_hash)
    puts 'not implemented'
  end

  def ip(app_hash)
    puts 'not implemented'
  end
end