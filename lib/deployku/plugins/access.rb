require 'yaml'

module Deployku
  class AccessPlugin < Deployku::Plugin
    describe :add, '<USER>', 'adds ssh key for user from STDIN'
    def add(user_name)
      allow = check_system_rights(:admin)
      if !allow && get_users.count > 0
        # allow add first user without privileges
        puts "No rights."
        exit 1
      end
      key = $stdin.gets
      key.chomp! if key
      if !key || key == ''
        puts "No key."
        exit 1
      end
      name = Deployku.sanitize_app_name(user_name)
      user_add(user_name, key)
      puts "User '#{user_name}' has been added."
      unless allow
        # first user
        acl_system_set(user_name, 'admin')
      end
    end

    describe :delete, '<USER>', 'deletes user keys from authorized_keys', acl_sys: :admin
    def delete(user_name)
      user_delete(user_name)
      acl_system_set(user_name, '')
      apps = Deployku::AppPlugin.instance.get_app_list
      apps.each { |app| acl_set(app, user_name, '') }
      puts "All keys for user '#{name}' has been removed."
    end

    describe :show, '', 'shows authorized_keys file', acl_sys: :admin
    def show
      puts File.read(authorized_keys_path)
    end

    describe :list, '', 'list user names', acl_sys: :admin
    def list
      p get_users
    end

    describe 'acl:set', '<APP> <USER> [LIST OF RIGHTS]', 'add user priviledges to application', acl_sys: :admin
    def acl_set(app_name, user_name, rights='')
      name = Deployku.sanitize_app_name(user_name)
      urights = { name => rights.split(',').map { |r| r.chomp } }
      rights = {}
      if File.exists?(app_acl_path(app_name))
        rights = YAML.load_file(app_acl_path(app_name))
      end
      rights.merge!(urights)
      File.open(app_acl_path(app_name), 'w') do |f|
        f << rights.to_yaml
      end
      puts "Application acl has been updated."
    end

    describe 'acl:system_set', '<USER> [LIST OF RIGHTS]', 'add system wide privileges', acl_sys: :admin
    def acl_system_set(user_name, rights='')
      name = Deployku.sanitize_app_name(user_name)
      urights = { name => rights.split(',').map { |r| r.chomp } }
      rights = {}
      if File.exists?(system_acl_path)
        rights = YAML.load_file(system_acl_path)
      end
      rights.merge!(urights)
      File.open(system_acl_path, 'w') do |f|
        f << rights.to_yaml
      end
      puts "System rights has been updated."
    end

    describe 'acl:list', '', 'lists all acls', acl_sys: :admin
    def acl_list
      users = get_users
      apps = Deployku::AppPlugin.instance.get_app_list
      rights = File.exists?(system_acl_path) ? YAML.load_file(system_acl_path) : {}
      users.each do |user|
        puts "#{user}:"
        puts "  system wide rights: #{rights[user]}"
        apps.each do |app|
          app_rights = File.exists?(app_acl_path(app)) ? YAML.load_file(app_acl_path(app)) : {}
          puts "  #{app}: #{app_rights[user]}"
        end
      end
    end

    describe 'acl:list_rights', '', 'lists available rights', acl_sys: :admin
    def acl_list_rights
      puts 'admin'
      puts 'commit'
    end

    def check_app_rights(app_name, right, ex=false)
      p [app_name, right, ex]
      name = Deployku.sanitize_app_name(ENV['NAME'].to_s)
      app_rights = File.exists?(app_acl_path(app_name)) ? YAML.load_file(app_acl_path(app_name)) : {}
      return true if app_rights[name] && (app_rights[name].include?(right.to_s) || app_rights[name].include?('admin'))
      return check_system_rights(right, ex)
    end

    def check_system_rights(right, ex=false)
      p [right, ex]
      name = Deployku.sanitize_app_name(ENV['NAME'].to_s)
      rights = File.exists?(system_acl_path) ? YAML.load_file(system_acl_path) : {}
      return true if rights[name] && (rights[name].include?(right.to_s) || rights[name].include?('admin'))
      if ex
        puts "No rights."
        exit 1
      end
      false
    end

    def user_add(user_name, key)
      name = Deployku.sanitize_app_name(user_name)
      File.open(authorized_keys_path, 'a') do |f|
        f << "command=\"NAME=#{name} `cat #{sshcommand_path}` $SSH_ORIGINAL_COMMAND\",no-agent-forwarding,no-user-rc,no-X11-forwarding,no-port-forwarding #{key}\n"
      end
    end

    def user_delete(user_name)
      name = Deployku.sanitize_app_name(user_name)
      lines = File.readlines(authorized_keys_path)
      File.open(authorized_keys_path, 'w') do |f|
        lines.each do |line|
          f << "#{line}\n" unless line =~ /NAME=#{name}/
        end
      end
    end

    def get_users
      users = []
      File.open(authorized_keys_path, 'r') do |f|
        while l = f.gets
          users << $1 if l =~ /NAME=([^\s]+)/
        end
      end if File.exists?(authorized_keys_path)
      users
    end

    def app_acl_path(app_name)
      File.join(Deployku::AppPlugin.instance.dir(app_name), 'DEPLOYKU_ACL.yml')
    end

    def system_acl_path
      File.join(Deployku::Config.home, '.deployku_acl.yml')
    end

    def sshcommand_path
      File.join(Deployku::Config.home, '.sshcommand')
    end

    def authorized_keys_path
      File.join(Deployku::Config.home, '.ssh/authorized_keys')
    end
  end
end