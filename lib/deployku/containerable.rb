module Deployku::Containerable
  def start(app_name)
    Deployku::Config.load(config_path(app_name))
    app_name = Deployku.sanitize_app_name(app_name)
    app_hash = Deployku::Engine.start(app_name, dir(app_name))
    exit 1 if $?.nil? || $?.exitstatus != 0
    set_container_id(app_name, app_hash)
    puts "Container #{app_hash} started."
  end

  def run(app_name, *cmd)
    Deployku::Config.load(config_path(app_name))
    app_name = Deployku.sanitize_app_name(app_name)
    Deployku::Engine.run(app_name, dir(app_name), *cmd)
    exit 1 if $?.nil? || $?.exitstatus != 0
  end

  def stop(app_name, cid: nil)
    Deployku::Config.load(config_path(app_name))
    app_hash = cid ? cid : get_container_id(app_name)
    if app_hash
      Deployku::Engine.stop(app_hash)
    end
  end

  def restart(app_name)
    old_cid = get_container_id(app_name)
    if start(app_name)
      # stops old application only if new instance was spawn
      stop(app_name, cid: old_cid) if old_cid
    end
  end

  def logs(app_name)
    Deployku::Config.load(config_path(app_name))
    app_hash = get_container_id(app_name)
    Deployku::Engine.logs(app_hash)
  end


  def container_id_path(app_name)
    File.join(dir(app_name), 'CONTAINER_ID')
  end

  def get_container_id(app_name)
    container_hash_path = container_id_path(app_name)
    if File.exists?(container_hash_path)
      File.read(container_hash_path)
    else
      nil
    end
  end

  def set_container_id(app_name, hash)
    container_hash_path = container_id_path(app_name)
    File.open(container_hash_path, 'w') do |f|
      f << hash
    end
  end

  def status(app_name)
    s = get_status(app_name)
    if s == nil
      puts 'Container does not exist.'
    else
      if s == true
        puts 'Container is running.'
      else
        puts 'Container is not running.'
      end
    end
  end

  def get_status(app_name)
    cid = get_container_id(app_name)
    if cid
      Deployku::Engine.running?(cid)
    else
      nil
    end
  end
end