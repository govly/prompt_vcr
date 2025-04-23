# PromptVCR

PromptVCR is a Rails engine that provides a UI for browsing and viewing AI prompt/response VCR cassettes. It makes it easy to visualize and debug your AI interactions during development and testing.

## Installation

PromptVCR is available directly via git source. Add this line to your application's Gemfile:

```ruby
gem "prompt_vcr", git: "https://github.com/govly/prompt_vcr.git", branch: "main", group: [:development, :test]
```

And then execute:

```bash
$ bundle install
```

## Configuration

### 1. Mount the Engine

Add this line to your `config/routes.rb` file to mount the engine:

```ruby
if Rails.env.local?
  mount PromptVCR::Engine, at: "/prompt_vcr"
end
```

This will make the UI available at `/prompt_vcr` in your application.

### 2. Cassette Locations

By default, PromptVCR looks for cassettes in these locations:
- General VCR cassettes: `test/vcr_cassettes` in your host application
- Prompt-specific cassettes: `test/vcr_cassettes/prompts` in your host application

No additional configuration is required if you use these default locations.

If you need to customize the locations, you can configure them in an initializer:

```ruby
# config/initializers/prompt_vcr.rb
PromptVCR.configure do |config|
  # For all VCR cassettes
  config.cassettes_path = Rails.root.join("your/custom/cassettes/path")
  
  # For prompt-specific cassettes
  config.prompt_cassettes_path = Rails.root.join("your/custom/prompt/cassettes/path")
end
```

You can configure just one or both paths as needed.

## Usage

Once the engine is mounted, navigate to `/prompt_vcr` in your browser when running your application in development.

### Creating VCR Cassettes

This engine provides only the viewer. To create cassettes, you'll need to use a VCR[VCR](https://github.com/vcr/vcr).

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
