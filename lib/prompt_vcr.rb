# Load inflections first to ensure VCR is properly recognized as an acronym
require "prompt_vcr/inflections"

# Then load the rest of the files
require "prompt_vcr/version"
require "prompt_vcr/engine"
require "prompt_vcr/configuration"

module PromptVCR
  # Returns the path where all cassettes are stored
  # If custom path is not configured, defaults to the host app's test/vcr_cassettes directory
  def self.cassettes_path
    configuration.cassettes_path || Rails.root.join("test", "vcr_cassettes")
  end
  
  # Returns the path where prompt cassettes are stored
  # If custom path is not configured, defaults to the host app's test/vcr_cassettes/prompts directory
  def self.prompt_cassettes_path
    configuration.prompt_cassettes_path || Rails.root.join("test", "vcr_cassettes", "prompts")
  end
end

# Provide a backward compatibility alias for Rails autoloading
# This helps with the transition from PromptVcr to PromptVCR
PromptVcr = PromptVCR unless defined?(PromptVcr)
