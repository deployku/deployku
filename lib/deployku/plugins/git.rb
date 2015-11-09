require 'tmpdir'

module Deployku
  class GitPlugin < Deployku::Plugin
    # describe :receive_pack, '<APP>', 'receives new commit'
    def receive_pack app_name
      unless app_name
        exit 1
      end
      app_name = app_name.gsub(%r{'([^']+)'}, '\1')
      app_dir = Deployku::AppPlugin.instance.create(app_name)
      create_receive_hook(app_dir, File.basename(app_dir))
      system "git-shell -c \"git-receive-pack '#{app_dir}'\""
    end

    describe :hook, '<APP>', 'receives new commit and builds new image', acl_app: { 0 => :commit }
    def hook(app_name)
      exit 1 unless app_name
      app_dir = Deployku::AppPlugin.instance.dir(app_name)
      app_name = File.basename(app_dir)
      unless Dir.exists?(app_dir)
        puts "Application directory '#{app_dir}' does not exist."
        exit 1
      end

      while line = $stdin.gets
        old_rev, new_rev, branch = line.chomp.split(' ')
        if branch != 'refs/heads/master'
          puts 'Only master branch is supported now.'
          exit 1
        end
      end
      unless new_rev
        puts 'Missing new revision number'
        exit 1
      end
      Deployku::AppPlugin.instance.rebuild(app_name, new_rev)
    end

    protected

    def create_receive_hook(app_dir, app_name)
      receive_hook_path = File.join(app_dir, 'hooks/pre-receive')
      File.open(receive_hook_path, 'w') do |f|
        f << <<EOF
#!/usr/bin/env bash
set -e; set -o pipefail;

cat | #{$0} git:hook '#{app_name}'
EOF
      end
      File.chmod(0755, receive_hook_path)
      receive_hook_path
    end
  end
end