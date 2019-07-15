
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "capistrano-rsync-plugin"
  spec.version       = "0.2.0"
  spec.authors       = ["Tom Armitage", "Stefan Daschek"]
  spec.email         = ["tom@infovore.org"]

  spec.summary       = %q{Plugin for Capitsrano 3.7+ to deploy with rsync}
  spec.description   = %q{Plugin for Capistrano 3.7+ to deploy with rsync, based on a Gist by Stefan Daschek.

  Ideally suited to deploying static sites made with static-site-generators.}
  spec.homepage      = "https://github.com/infovore/capistrano-rsync-plugin"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/infovore/capistrano-rsync-plugin"
    # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'capistrano', '>= 3.0.0.pre'

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
end
