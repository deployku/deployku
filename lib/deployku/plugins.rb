module Deployku

  class Plugin
    @plugins = []

    class NoMethod < NoMethodError
    end

    class << self
      attr_reader :plugins
    end

    def self.<<(plugin)
      @plugins << plugin
    end

    def self.find_plugin(name)
      plugin_name = "Deployku::#{name.capitalize}Plugin"
      @plugins.each do |plugin|
        return plugin if plugin.name == plugin_name
      end
      nil
    end

    def self.filter_plugins(fn)
      plugins = []
      @plugins.each do |plugin|
        plug = plugin.instance
        plugins << plug if plug.respond_to?(fn)
      end
      plugins
    end

    def self.inherited(plugin)
      Plugin << plugin
      plugin.instance_eval do
        @help_register = []
        class << self
          attr_reader :help_register
        end
        def describe(fn_name, args, description, acl={})
          @help_register << { name: fn_name, arg_list: args, desc: description, acl_app: acl[:acl_app], acl_sys: acl[:acl_sys] }
        end
      end
    end

    # collects info from 'describe' and returns it as a string
    def self.help
      str = ''
      help_register = []
      max_name_length = 0
      max_arg_length = 0
      max_desc_length = 0
      @plugins.each do |plugin|
        plugin.name =~ /Deployku::(.*?)Plugin/
        next unless $1
        name = $1.downcase
        plugin.help_register.each do |reg|
          new_reg = { name: "#{name}:#{reg[:name]}", args: reg[:arg_list], desc: reg[:desc] }
          max_name_length = new_reg[:name].length if new_reg[:name].length > max_name_length
          max_arg_length = new_reg[:args].length if new_reg[:args].length > max_arg_length
          max_desc_length = new_reg[:desc].length if new_reg[:desc].length > max_desc_length
          help_register << new_reg
        end
      end
      help_register.each do |reg|
        str << "   %-#{max_name_length}s %-#{max_arg_length}s %s\n" % [reg[:name], reg[:args], reg[:desc]]
      end
      str
    end

    # run command in a plugin
    def self.run(fn, args=[])
      fn_name = fn.to_s.gsub(':', '_')
      fn_desc = command_description(fn)
      unless fn_desc
        puts "Unknown command '#{fn}'."
        exit 1
      end
      if fn_desc[:acl_app]
        fn_desc[:acl_app].each do |idx, right|
          Deployku::AccessPlugin.instance.check_app_rights(args[idx], right, true)
        end
      end
      if fn_desc[:acl_sys]
        Deployku::AccessPlugin.instance.check_system_rights(fn_desc[:acl_sys], true)
      end
      plug = instance
      raise Deployku::Plugin::NoMethod.new("no method '#{plug.class.name}.#{fn}'") unless plug.respond_to?(fn_name)
      plug.send(fn_name, *args)
    end

    def self.instance
      @instance ||= self.new
    end

    def self.command_description(fn)
      self.help_register.each do |reg|
        return reg if reg[:name].to_s == fn.to_s
      end
      nil
    end

    # concatenate system wide packages and packages required by plugin
    def packages
      Deployku::Config.packages + self.class::PACKAGES
    end

  end

end