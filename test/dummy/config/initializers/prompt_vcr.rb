# Configure PromptVCR settings
PromptVCR.configure do |config|
  # Set base cassettes path
  config.cassettes_path = Rails.root.join("test", "vcr_cassettes")
  
  # Add any custom prompt endpoints if needed
  # config.add_prompt_endpoint("your_custom_llm_endpoint.com")
end
