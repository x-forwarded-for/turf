# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "turf/version"

Gem::Specification.new do |spec|
  spec.name          = "turf"
  spec.version       = Turf::VERSION
  spec.authors       = ["Luke Jahnke", "Thiébaud Weksteen"]
  spec.summary       = %q{Turf}
  spec.description   = %q{Turf}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "colorize", "~> 0.7", ">= 0.7.7"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.4"
  spec.add_development_dependency "simplecov", "~> 0.10"
  spec.add_development_dependency "rubocop", "~> 0.32"
end

