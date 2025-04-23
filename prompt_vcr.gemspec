require_relative "lib/prompt_vcr/version"

Gem::Specification.new do |spec|
  spec.name        = "prompt_vcr"
  spec.version     = PromptVCR::VERSION
  spec.authors     = [ "Govly" ]
  spec.email       = [ "engineering@govly.com" ]
  spec.homepage    = "https://github.com/govly/prompt_vcr"
   spec.summary    = "A VCR UI for prompts"
  spec.description = "A VCR UI for prompts"
  spec.license     = "MIT"

  # This is a private gem, not meant for public distribution for now.
  spec.metadata["allowed_push_host"] = "https://github.com/govly/prompt_vcr"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/weilandia/prompt_vcr"
  spec.metadata["changelog_uri"] = "https://github.com/weilandia/prompt_vcr/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md"]
  end

  spec.require_paths = ["lib"]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.add_dependency "rails", ">= 8.0.1"
end
