dir = File.expand_path(File.dirname(__FILE__))
$:.unshift(dir) unless $:.include?(dir)

require 'deployku/config'
require 'deployku/helpers'
require 'deployku/configurable'
require 'deployku/containerable'
require 'deployku/plugins'
require 'deployku/engine'

# load core plugins
require 'deployku/plugins/access'
require 'deployku/plugins/docker'
require 'deployku/plugins/lxc'
require 'deployku/plugins/app'
require 'deployku/plugins/git'
require 'deployku/plugins/postgres'
require 'deployku/plugins/rails'
require 'deployku/plugins/nginx'