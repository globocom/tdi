# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'tdi/version'

Gem::Specification.new do |spec|
  spec.name          = 'tdi'
  spec.version       = Tdi::VERSION
  spec.authors       = ['Rogério Carvalho Schneider', 'Diogo Kiss', 'Francisco Corrêa']
  spec.email         = ['rogerio.schneider@corp.globo.com', 'diogokiss@corp.globo.com', 'francisco@corp.globo.com']
  spec.summary       = %q(Test Driven Infrastructure)
  spec.description   = %q(Test Driven Infrastructure acceptance helpers for
validating your deployed infrastructure and external dependencies.)
  spec.homepage      = 'https://github.com/globocom/tdi'
  spec.license       = 'GPL-3.0'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib', 'helpers']

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake'

  spec.add_runtime_dependency 'os'
  spec.add_runtime_dependency 'etc'
  spec.add_runtime_dependency 'slop', '~> 3.6'
  spec.add_runtime_dependency 'colorize'
  spec.add_runtime_dependency 'timeout', '0.0.0'
  spec.add_runtime_dependency 'net-ssh'
  spec.add_runtime_dependency 'awesome_print'
  spec.add_runtime_dependency 'ipaddress'
  spec.add_runtime_dependency 'dnsruby'
end
