require 'date'
require_relative 'lib/enkrip/version'

Gem::Specification.new do |s|
  s.name        = 'enkrip'
  s.version     = Enkrip::VERSION
  s.date        = Date.today.to_s
  s.summary     = 'encrypt & decrypt Active Record attributes with Message Encryptor'
  s.description = 'encrypt & decrypt Active Record attributes with Message Encryptor'
  s.author      = 'Kunto Aji Kristianto'
  s.email       = 'kuntoaji@kaklabs.com'
  s.files       = `git ls-files -z`.split("\x0")
  s.homepage    = 'http://github.com/kuntoaji/enkrip'
  s.license     = 'MIT'
end
