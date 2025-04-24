module PromptVCR
  class Configuration
    attr_accessor :cassettes_path
    attr_reader :prompt_endpoints

    def initialize
      @cassettes_path = defined?(Rails) ? Rails.root.join("test", "vcr_cassettes") : nil
      @prompt_endpoints = [
        "/chat/completions",
        "/completions",
        "/embeddings",
        "api.openai.com",
        "api.anthropic.com",
        "generativelanguage.googleapis.com"
      ]
    end

    def add_prompt_endpoint(endpoint)
      @prompt_endpoints << endpoint unless @prompt_endpoints.include?(endpoint)
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
