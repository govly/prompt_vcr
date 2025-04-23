module PromptVCR
  class Configuration
    attr_accessor :cassettes_path, :prompt_cassettes_path

    def initialize
      @cassettes_path = nil
      @prompt_cassettes_path = nil
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
