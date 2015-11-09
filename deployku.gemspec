# -*- coding: utf-8 -*-
# vi: fenc=utf-8:expandtab:ts=2:sw=2:sts=2
# 
# @author: Petr Kovar <pejuko@gmail.com>

require 'rubygems'
require 'find'

spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.summary = "Deploy applications using git with zero down time"
  s.homepage = "http://github.com/deployku/deployku"
  s.email = "pejuko@gmail.com"
  s.authors = ["Petr Kovář"]
  s.name = 'deployku'
  s.version = '0.0.1'
  s.date = Time.now.strftime("%Y-%m-%d")
  s.require_path = 'lib'
  s.files = ["bin/deployku", "README.md", "deployku.gemspec", "Rakefile", "LICENSE"]
  s.files += Dir["lib/**/*.rb"]
  s.executables = ["deployku"]
end

