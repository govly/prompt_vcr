# Load inflections first to ensure VCR is properly recognized as an acronym
require "prompt_vcr/inflections"

# Then load the rest of the files
require "prompt_vcr/version"
require "prompt_vcr/engine"
require "prompt_vcr/configuration"

module PromptVCR
  # Returns the path where all cassettes are stored
  # Uses the default from configuration if not specified
  def self.cassettes_path
    configuration.cassettes_path
  end
end

# Provide a backward compatibility alias for Rails autoloading
# This helps with the transition from PromptVcr to PromptVCR
PromptVcr = PromptVCR unless defined?(PromptVcr)
