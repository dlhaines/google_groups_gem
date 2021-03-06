# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ggb/version'

Gem::Specification.new do |spec|
  spec.name          = "ggb"
  spec.version       = GGB::VERSION
  spec.authors       = ["David Haines"]
  spec.email         = ["dlhaines@umich.edu"]

  spec.summary       = 'Wrapper for Google Groups for Business'
  #spec.description   = %q{TODO: Write a longer description or delete this line.}

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_dependency "googleauth"
  spec.add_dependency 'google-api-client'
  
  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_development_dependency 'minitest'

  spec.add_development_dependency 'activesupport', '4.2.5'
  spec.add_development_dependency 'shoulda'

end
