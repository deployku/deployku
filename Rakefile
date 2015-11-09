# -*- coding: utf-8 -*-
# vi: fenc=utf-8:expandtab:ts=2:sw=2:sts=2
# 
# @author: Petr Kovar <pejuko@gmail.com>

require 'rubygems/package_task'
require 'rake/clean'

CLEAN << "pkg"

task :default => [:gem]

Gem::PackageTask.new(eval(File.read("deployku.gemspec"))) {|pkg|}

