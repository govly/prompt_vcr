require_relative "lib/prompt_vcr/version"

Gem::Specification.new do |spec|
  spec.name        = "prompt_vcr"
  spec.version     = PromptVcr::VERSION
  spec.authors     = [ "Nick Weiland" ]
  spec.email       = [ "nickweiland@gmail.com" ]
  spec.homepage    = "https://github.com/weilandia/prompt_vcr"
  spec.summary     = "A VCR-like library for recording and replaying AI prompts"
  spec.description = "PromptVcr provides a way to record and replay AI prompts for testing purposes"
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # spec.metadata["allowed_push_host"] = "http://mygemserver.com"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/weilandia/prompt_vcr"
  spec.metadata["changelog_uri"] = "https://github.com/weilandia/prompt_vcr/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.0.1"
end
