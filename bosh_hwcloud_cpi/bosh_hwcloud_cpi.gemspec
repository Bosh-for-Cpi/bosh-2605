# coding: utf-8
require File.expand_path('../lib/cloud/hwcloud/version', __FILE__)

version = Bosh::HwCloud::VERSION

Gem::Specification.new do |s|
  s.name         = 'bosh_qingcloud_cpi'
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'BOSH HwCloud CPI'
  s.description  = "BOSH HwCloud CPI\n#{`git rev-parse HEAD`[0, 6]}"
  s.author       = 'VMware'
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = 'support@cloudfoundry.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  #s.files        = `git ls-files -- bin/* lib/* scripts/*`.split("\n") + %w(README.md)
  s.files        = Dir.glob("bin/**/*") + Dir.glob("lib/**/*") + Dir.glob("scripts/**/*") + %w(README.md)
  s.require_path = 'lib'
  s.bindir       = 'bin'
  s.executables  = %w(bosh_qingcloud_console)

#  s.add_dependency 'hwcloud-sdk',       '=0.8.7'
  s.add_dependency 'bosh_common',   "~>#{version}"
  s.add_dependency 'bosh_cpi',      "~>#{version}"
  s.add_dependency 'bosh-registry', "~>#{version}"
  s.add_dependency 'rubypython',    '=0.6.3'
  s.add_dependency 'httpclient',    '=2.2.4'
  s.add_dependency 'yajl-ruby',     '>=0.8.2'
end
