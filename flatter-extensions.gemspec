# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'flatter/extensions/version'

Gem::Specification.new do |spec|
  spec.name          = "flatter-extensions"
  spec.version       = Flatter::Extensions::VERSION
  spec.authors       = ["Artem Kuzko"]
  spec.email         = ["a.kuzko@gmail.com"]

  spec.summary       = %q{Set of extensions for Flatter gem.}
  spec.description   = %q{Set of extensions to be used with Flatter gem. They
    provide a number of optional auxiliary functionality, which may be very
    helpful from case to case, especially if using Flatter for mapping
    ActiveRecord objects}
  spec.homepage      = "https://github.com/akuzko/flatter-extensions"
  spec.license       = "MIT"

  spec.required_ruby_version = '>= 2.0.0'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "flatter"

  spec.add_development_dependency "activerecord", ">= 4.0"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-nav"
end
