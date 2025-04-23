# Load custom inflections first
require "prompt_vcr/inflections"

module PromptVCR
  class Engine < ::Rails::Engine
    isolate_namespace PromptVCR
    
    # Explicitly define this engine as mountable
    config.mountable = true
    
    # Load our custom inflections during engine initialization
    initializer "prompt_vcr.inflections" do
      ActiveSupport::Inflector.inflections(:en) do |inflect|
        inflect.acronym 'VCR'
      end
    end
  end
end
