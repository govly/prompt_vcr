require "fileutils"

module PromptVCR
  class CassetteParser
    attr_reader :base_dir

    def initialize(base_dir = nil)
      @base_dir = base_dir || PromptVCR.cassettes_path

      # Create the base directory if it doesn't exist
      unless Dir.exist?(@base_dir)
        FileUtils.mkdir_p(@base_dir)
      end
    end

    # Determine if a cassette contains prompt interactions
    def prompt_cassette?(path_or_data)
      if path_or_data.is_a?(String)
        # It's a path, we need to load the data
        data = load_cassette(path_or_data)
        return false unless data
        contains_prompt_interaction?(data)
      else
        # It's already loaded data
        contains_prompt_interaction?(path_or_data)
      end
    end

    # Check if data contains prompt interactions
    def contains_prompt_interaction?(data)
      return false unless data

      # Direct indicators in the data
      return true if data["prompt"].present? || data["completion"].present?
      return true if data["metadata"] && data["metadata"]["type"] == "prompt"

      # Check HTTP interactions
      if data["http_interactions"].present?
        data["http_interactions"].each do |interaction|
          return true if is_prompt_interaction?(interaction)
        end
      end

      false
    end

    # Check if an individual HTTP interaction is a prompt
    def is_prompt_interaction?(interaction)
      return false unless interaction.is_a?(Hash)

      # Check if it's an AI API request
      req = interaction["request"]
      return false unless req

      # Check URI against configured prompt endpoints
      if req["uri"]
        PromptVCR.configuration.prompt_endpoints.each do |endpoint|
          return true if req["uri"].include?(endpoint)
        end
      end

      # Check request body for prompt indicators
      if req["body"] && req["body"]["string"]
        begin
          body = JSON.parse(req["body"]["string"])
          return true if body["model"].present? || body["messages"].present? ||
                        body["prompt"].present? || body["text"].present?
        rescue
          # Not JSON or couldn't parse
        end
      end

      # Check for response indicators
      if interaction["response"] && interaction["response"]["body"] && interaction["response"]["body"]["string"]
        begin
          body = JSON.parse(interaction["response"]["body"]["string"])
          return true if body["choices"].present? || body["embedding"].present? ||
                        body["embeddings"].present? || body["completion"].present?
        rescue
          # Not JSON or couldn't parse
        end
      end

      false
    end

    def list_cassettes(only_prompts = false)
      all_files = []

      if Dir.exist?(@base_dir)
        files = Dir.glob(File.join(@base_dir, "**/*.yml"))
        all_files.concat(files)
      end

      # We now need to load each cassette to check its content if only_prompts filtering is requested
      if only_prompts
        all_files = all_files.select do |file|
          data = YAML.load_file(file) rescue nil
          data && contains_prompt_interaction?(data)
        end
      end

      # Map to relative paths
      all_files.map do |file|
        file.sub("#{@base_dir}/", "").sub(".yml", "")
      end.sort
    end

    def list_cassettes_by_type
      result = { prompts: [], others: [] }

      if Dir.exist?(@base_dir)
        Dir.glob(File.join(@base_dir, "**/*.yml")).each do |file|
          # Create relative path
          rel_path = file.sub("#{@base_dir}/", "").sub(".yml", "")

          # Load the cassette data to check its content
          data = YAML.load_file(file) rescue nil

          if data && contains_prompt_interaction?(data)
            result[:prompts] << rel_path
          else
            result[:others] << rel_path
          end
        end
      end

      result[:prompts].sort!
      result[:others].sort!
      result
    end

    def load_cassette(name)
      # Try to find the cassette in the base directory
      possible_paths = []

      # Standard path
      possible_paths << File.join(@base_dir, "#{name}.yml")

      # Legacy support for prompts directory
      clean_name = name.sub(/^prompts\//, "")
      possible_paths << File.join(@base_dir, "#{clean_name}.yml")

      # If we're looking in a subdirectory
      if name.include?("/")
        # Also try with just the filename part
        basename = File.basename(name)
        possible_paths << File.join(@base_dir, "#{basename}.yml")
      end

      # Try all possible paths
      found_path = possible_paths.find { |path| File.exist?(path) }

      if found_path
        Rails.logger.info("Loading cassette from file: #{found_path}")
        begin
          YAML.load_file(found_path)
        rescue => e
          Rails.logger.error("Error loading cassette: #{e.message}")
          nil
        end
      else
        paths_tried = possible_paths.join(", ")
        Rails.logger.error("Cassette file not found. Tried paths: #{paths_tried}")
        nil
      end
    end

    def file_created_at(name)
      # Use the same path finding logic as in load_cassette
      possible_paths = []

      # Standard path
      possible_paths << File.join(@base_dir, "#{name}.yml")

      # Legacy support for prompts directory
      clean_name = name.sub(/^prompts\//, "")
      possible_paths << File.join(@base_dir, "#{clean_name}.yml")

      # If we're looking in a subdirectory
      if name.include?("/")
        # Also try with just the filename part
        basename = File.basename(name)
        possible_paths << File.join(@base_dir, "#{basename}.yml")
      end

      # Try all possible paths
      found_path = possible_paths.find { |path| File.exist?(path) }

      found_path ? File.ctime(found_path) : nil
    end

    def file_updated_at(name)
      # Use the same path finding logic as in load_cassette
      possible_paths = []

      # Standard path
      possible_paths << File.join(@base_dir, "#{name}.yml")

      # Legacy support for prompts directory
      clean_name = name.sub(/^prompts\//, "")
      possible_paths << File.join(@base_dir, "#{clean_name}.yml")

      # If we're looking in a subdirectory
      if name.include?("/")
        # Also try with just the filename part
        basename = File.basename(name)
        possible_paths << File.join(@base_dir, "#{basename}.yml")
      end

      # Try all possible paths
      found_path = possible_paths.find { |path| File.exist?(path) }

      found_path ? File.mtime(found_path) : nil
    end

    def delete_cassette(name)
      # Try to find the cassette in the base directory
      possible_paths = []

      # Standard path
      possible_paths << File.join(@base_dir, "#{name}.yml")

      # Legacy support for prompts directory
      clean_name = name.sub(/^prompts\//, "")
      possible_paths << File.join(@base_dir, "#{clean_name}.yml")

      # If we're looking in a subdirectory
      if name.include?("/")
        # Also try with just the filename part
        basename = File.basename(name)
        possible_paths << File.join(@base_dir, "#{basename}.yml")
      end

      # Try all possible paths
      found_path = possible_paths.find { |path| File.exist?(path) }

      if found_path
        begin
          File.delete(found_path)
          true
        rescue => e
          Rails.logger.error("Error deleting cassette: #{e.message}")
          false
        end
      else
        paths_tried = possible_paths.join(", ")
        Rails.logger.error("Cassette file not found for deletion. Tried paths: #{paths_tried}")
        false
      end
    end

    def extract_metadata(data, cassette_name)
      return {} unless data

      # Initialize with file metadata
      metadata = {
        created_at: file_created_at(cassette_name),
        updated_at: file_updated_at(cassette_name),
        model: "Unknown",
        provider: "Unknown",
        prompt_preview: "",
        name: nil,
        cassette_type: prompt_cassette?(cassette_name) ? "prompt" : "standard"
      }

      # Try to extract a name from the data
      if data["name"].present?
        metadata[:name] = data["name"]
      elsif data["metadata"] && data["metadata"]["name"].present?
        metadata[:name] = data["metadata"]["name"]
      elsif data["schema"] && data["schema"]["name"].present?
        metadata[:name] = data["schema"]["name"]
      end

      # Extract model information
      if data["request"] && data["request"]["model"]
        metadata[:model] = data["request"]["model"]
        metadata[:prompt_preview] = data["request"]["prompt"].to_s[0..100] if data["request"]["prompt"]
      elsif data["http_interactions"] && data["http_interactions"].first && data["http_interactions"].first["request"] && data["http_interactions"].first["request"]["body"] && data["http_interactions"].first["request"]["body"]["string"]
        begin
          req_data = JSON.parse(data["http_interactions"].first["request"]["body"]["string"])
          # Extract model from various OpenAI API formats
          if req_data["model"]
            metadata[:model] = req_data["model"]
          end

          # Handle different input formats
          if req_data["input"]
            metadata[:prompt_preview] = req_data["input"].to_s[0..100]
          elsif req_data["messages"] && req_data["messages"].first && req_data["messages"].first["content"]
            metadata[:prompt_preview] = req_data["messages"].first["content"].to_s[0..100]
            # For chat API, the model might be directly in the URL path
            if data["http_interactions"].first["request"]["uri"] && data["http_interactions"].first["request"]["uri"].include?("/v1/")
              uri_parts = data["http_interactions"].first["request"]["uri"].split("/")
              if uri_parts.include?("chat") && uri_parts.include?("completions") && metadata[:model] == "Unknown"
                metadata[:model] = "gpt-4" # Default assumption for chat API
              end
            end
          end
        rescue
          # If JSON parsing fails, use the raw string
          metadata[:prompt_preview] = data["http_interactions"].first["request"]["body"]["string"].to_s[0..100]
        end
      end

      # Extract provider information
      if data["metadata"] && data["metadata"]["provider"]
        metadata[:provider] = data["metadata"]["provider"]
      end

      # Use metadata created_at if available
      if data["metadata"] && data["metadata"]["created_at"]
        begin
          metadata[:created_at] = Time.parse(data["metadata"]["created_at"])
        rescue
          # Keep the file created time if parsing fails
        end
      end

      metadata
    end

    def extract_structured_data(cassette_data)
      return { has_structured_data: false } unless cassette_data

      if cassette_data["http_interactions"]
        extract_structured_data_from_http_interaction(cassette_data["http_interactions"].first)
      else
        extract_structured_data_from_direct_format(cassette_data)
      end
    end

    # Helper method to safely format JSON for display
    def safe_format_json(data)
      if data.is_a?(String)
        begin
          # Try to parse and pretty print
          formatted = JSON.pretty_generate(JSON.parse(data))
          # Ensure UTF-8 encoding
          formatted.force_encoding('UTF-8')
        rescue
          # If parsing fails, just return the string with UTF-8 encoding
          data.to_s.force_encoding('UTF-8')
        end
      elsif data.is_a?(Hash) || data.is_a?(Array)
        begin
          # Pretty print hash/array
          formatted = JSON.pretty_generate(data)
          # Ensure UTF-8 encoding
          formatted.force_encoding('UTF-8')
        rescue
          # If pretty print fails, fall back to string representation
          data.to_s.force_encoding('UTF-8')
        end
      else
        # For other types, convert to string with UTF-8 encoding
        data.to_s.force_encoding('UTF-8')
      end
    end

    # Extract structured data from an HTTP interaction
    def extract_structured_data_from_http_interaction(interaction)
      return { has_structured_data: false } unless interaction

      structured_data = { has_structured_data: false }
      
      # Attempt to parse response as JSON
      if interaction["response"] && interaction["response"]["body"] && interaction["response"]["body"]["string"]
        begin
          raw_response = interaction["response"]["body"]["string"]
          response_json = JSON.parse(raw_response)
          # Format the response JSON for safe display
          structured_data[:json_response] = response_json
          structured_data[:formatted_json_response] = safe_format_json(response_json)
          structured_data[:has_structured_data] = true
          
          # Extract the model information (handle different API formats)
          if response_json["model"]
            structured_data[:model] = response_json["model"]
          end
          
          # Extract token information
          if response_json["usage"]
            structured_data[:token_usage] = response_json["usage"]
            structured_data[:formatted_token_usage] = safe_format_json(response_json["usage"])
          end

          # Handle different response formats
          if response_json["choices"] && response_json["choices"].first
            # OpenAI API response for chat or completions API
            structured_output = []
            
            if response_json["choices"].first["message"] && response_json["choices"].first["message"]["content"]
              # Chat completions API
              structured_output << {
                name: "Response",
                type: "text",
                value: response_json["choices"].first["message"]["content"]
              }
              structured_data[:content] = response_json["choices"].first["message"]["content"]
            elsif response_json["choices"].first["text"]
              # Completions API
              structured_output << {
                name: "Response",
                type: "text",
                value: response_json["choices"].first["text"]
              }
              structured_data[:content] = response_json["choices"].first["text"]
            end
            
            # Add metadata fields
            if response_json["usage"]
              structured_output << {
                name: "Token Usage",
                type: "json",
                value: safe_format_json(response_json["usage"])
              }
            end
            
            structured_data[:structured_output] = structured_output
            structured_data[:has_structured_output] = structured_output.any?
          elsif response_json["data"] && response_json["data"]["embeddings"]
            # Embeddings API
            structured_data[:structured_output] = [
              {
                name: "Embeddings",
                type: "json",
                value: safe_format_json(response_json["data"]["embeddings"])
              }
            ]
            structured_data[:has_structured_output] = true
          elsif response_json["success"] && response_json["data"]
            # Handle success: true API format (like FireCrawl and others)
            structured_output = []
            
            # Extract any text/markdown content
            if response_json["data"]["markdown"]
              structured_output << {
                name: "Markdown",
                type: "text",
                value: response_json["data"]["markdown"]
              }
              structured_data[:content] = response_json["data"]["markdown"]
            elsif response_json["data"]["text"]
              structured_output << {
                name: "Text",
                type: "text",
                value: response_json["data"]["text"]
              }
              structured_data[:content] = response_json["data"]["text"]
            end
            
            # Add additional data fields
            response_json["data"].each do |key, value|
              next if ["text", "markdown"].include?(key) # Skip already handled fields
              next if value.is_a?(String) && value.length > 1000 # Skip long text fields
              
              structured_output << {
                name: key.to_s.humanize,
                type: value.is_a?(Hash) || value.is_a?(Array) ? "json" : "text",
                value: value
              }
            end
            
            structured_data[:structured_output] = structured_output
            structured_data[:has_structured_output] = structured_output.any?
          elsif response_json["output"] && response_json["output"].is_a?(Array)
            # Handle output array format (like some Anthropic API responses and others)
            structured_output = []
            
            # Look for content in message objects
            content_found = false
            response_json["output"].each do |item|
              if item["content"] && item["content"].is_a?(Array)
                item["content"].each do |content_item|
                  if content_item["text"]
                    structured_output << {
                      name: "Content",
                      type: "text",
                      value: content_item["text"]
                    }
                    structured_data[:content] ||= content_item["text"]
                    content_found = true
                  end
                end
              elsif item["type"] && item["type"] == "message" && item["content"]
                # Handle nested content arrays or direct content
                if item["content"].is_a?(Array)
                  item["content"].each do |content_item|
                    if content_item["text"]
                      structured_output << {
                        name: "Content",
                        type: "text",
                        value: content_item["text"]
                      }
                      structured_data[:content] ||= content_item["text"]
                      content_found = true
                    end
                  end
                else
                  structured_output << {
                    name: "Content",
                    type: "text",
                    value: item["content"]
                  }
                  structured_data[:content] ||= item["content"]
                  content_found = true
                end
              end
            end
            
            structured_data[:structured_output] = structured_output
            structured_data[:has_structured_output] = structured_output.any?
          end
        rescue => e
          # Not JSON or couldn't parse
          structured_data[:parse_error] = e.message
        end
      end
      
      structured_data
    end
    
    # Extract structured data from direct format cassettes (non-HTTP)
    def extract_structured_data_from_direct_format(cassette_data)
      return { has_structured_data: false } unless cassette_data

      structured_data = { has_structured_data: false }

      if cassette_data["response"] && cassette_data["response"]["content"]
        structured_data[:has_structured_data] = true
        structured_data[:content] = cassette_data["response"]["content"]

        # Extract structured output if available
        if cassette_data["response"]["structured_output"]
          structured_output = []

          cassette_data["response"]["structured_output"].each do |key, value|
            structured_output << {
              name: key.to_s.humanize,
              type: value.is_a?(Hash) || value.is_a?(Array) ? "json" : "text",
              value: value
            }
          end

          structured_data[:structured_output] = structured_output
          structured_data[:has_structured_output] = structured_output.any?
        end
      end

      structured_data
    end

    # Extract just the request schema (for displaying input expectations)
    def extract_request_schema(cassette_data)
      return { has_schema: false } unless cassette_data

      if cassette_data["http_interactions"]
        extract_request_schema_from_http_interaction(cassette_data["http_interactions"].first)
      else
        extract_request_schema_from_direct_format(cassette_data)
      end
    end

    # Extract schema from an HTTP interaction
    def extract_request_schema_from_http_interaction(interaction)
      return { has_schema: false } unless interaction

      schema_data = { has_schema: false }

      # Check if there's a schema in the request
      if interaction["request"] && interaction["request"]["body"] && interaction["request"]["body"]["string"]
        begin
          body = JSON.parse(interaction["request"]["body"]["string"])

          # Check for schema in different formats
          if body["schema"]
            schema_data[:schema] = body["schema"]
            schema_data[:has_schema] = true
            schema_data[:schema_name] = body["schema"]["name"] || "Input Schema"
          elsif body["messages"] && body["messages"].any? { |m| m["schema"] }
            # Find a message with schema
            message_with_schema = body["messages"].find { |m| m["schema"] }
            schema_data[:schema] = message_with_schema["schema"]
            schema_data[:has_schema] = true
            schema_data[:schema_name] = message_with_schema["schema"]["name"] || "Chat Message Schema"
          end

          # If we find a function call, extract its parameters as a schema
          if body["functions"] && body["functions"].first && body["functions"].first["parameters"]
            schema_data[:schema] = body["functions"].first["parameters"]
            schema_data[:has_schema] = true
            schema_data[:schema_name] = body["functions"].first["name"] || "Function Parameters"
          end
        rescue => e
          # Not JSON or couldn't parse
          Rails.logger.debug("Failed to parse request body for schema: #{e.message}")
        end
      end

      schema_data
    end

    # Extract schema from direct format cassettes
    def extract_request_schema_from_direct_format(cassette_data)
      return { has_schema: false } unless cassette_data

      schema_data = { has_schema: false }

      if cassette_data["request"] && cassette_data["request"]["schema"]
        schema_data[:schema] = cassette_data["request"]["schema"]
        schema_data[:has_schema] = true
        schema_data[:schema_name] = cassette_data["request"]["schema"]["name"] || "Input Schema"
      end

      schema_data
    end
  end
end
