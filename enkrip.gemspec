require 'date'
require_relative 'lib/enkrip/version'

Gem::Specification.new do |spec|
  spec.name        = 'enkrip'
  spec.version     = Enkrip::VERSION
  spec.date        = Date.today.to_s
  spec.summary     = 'encrypt & decrypt Active Record attributes with Message Encryptor'
  spec.description = 'Enkrip will encrypt & decrypt Active Record attributes seamlessly with Message Encryptor. By default compatible with Active model validation'
  spec.author      = 'Kunto Aji Kristianto'
  spec.email       = 'kuntoaji@kaklabs.com'
  spec.files       = `git ls-files -z`.split("\x0")
  spec.homepage    = 'http://github.com/kuntoaji/enkrip'
  spec.license     = 'MIT'

  spec.add_dependency 'activerecord', '>= 5.2', '< 7'
  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'rake', '~> 12.3'
  spec.add_development_dependency 'minitest', '~> 5.11'
  spec.add_development_dependency 'sqlite3', '~> 0'
end
