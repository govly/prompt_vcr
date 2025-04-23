require 'fileutils'

module PromptVcr
  class CassetteParser
    attr_reader :base_dir

    # Directory constants
    PROMPTS_DIR = "prompts"
    
    def initialize(base_dir = nil, type = :prompts)
      if base_dir
        @base_dir = base_dir
      else
        case type
        when :prompts
          @base_dir = Rails.root.join("test/vcr_cassettes/prompts")
        when :all
          @base_dir = Rails.root.join("test/vcr_cassettes")
        else
          @base_dir = Rails.root.join("test/vcr_cassettes")
        end
      end
      
      # Create the directory if it doesn't exist
      unless Dir.exist?(@base_dir)
        FileUtils.mkdir_p(@base_dir)
      end
    end
    
    # Determine if a cassette is a prompt cassette
    def prompt_cassette?(path)
      path.include?(PROMPTS_DIR) || path.include?(PROMPTS_DIR.singularize)
    end

    def list_cassettes(only_prompts = false)
      if Dir.exist?(base_dir)
        files = Dir.glob(File.join(base_dir, "**/*.yml"))
        
        if only_prompts
          files = files.select { |file| prompt_cassette?(file) }
        end
        
        files.map { |file| file.sub("#{base_dir}/", "").sub(".yml", "") }.sort
      else
        []
      end
    end
    
    def list_cassettes_by_type
      result = { prompts: [], others: [] }
      
      if Dir.exist?(base_dir)
        Dir.glob(File.join(base_dir, "**/*.yml")).each do |file|
          rel_path = file.sub("#{base_dir}/", "").sub(".yml", "")
          if prompt_cassette?(file)
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
      # Determine the appropriate file path based on the cassette type
      possible_paths = []

      # Standard cassette path
      possible_paths << File.join(Rails.root, "test/vcr_cassettes", "#{name}.yml") 
      
      # Prompt cassette path (both with and without 'prompts/' prefix)
      clean_name = name.sub(/^prompts\//, '')
      possible_paths << File.join(Rails.root, "test/vcr_cassettes/prompts", "#{clean_name}.yml")
      
      # If name doesn't already have the subdirectory and it's a prompt cassette
      if prompt_cassette?(name) && !name.include?('/')
        possible_paths << File.join(Rails.root, "test/vcr_cassettes/prompts", "#{name}.yml")
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
      
      # Standard cassette path
      possible_paths << File.join(Rails.root, "test/vcr_cassettes", "#{name}.yml") 
      
      # Prompt cassette path (both with and without 'prompts/' prefix)
      clean_name = name.sub(/^prompts\//, '')
      possible_paths << File.join(Rails.root, "test/vcr_cassettes/prompts", "#{clean_name}.yml")
      
      # If name doesn't already have the subdirectory and it's a prompt cassette
      if prompt_cassette?(name) && !name.include?('/')
        possible_paths << File.join(Rails.root, "test/vcr_cassettes/prompts", "#{name}.yml")
      end
      
      # Try all possible paths
      found_path = possible_paths.find { |path| File.exist?(path) }
      
      found_path ? File.ctime(found_path) : nil
    end
    
    def file_updated_at(name)
      # Use the same path finding logic as in load_cassette
      possible_paths = []
      
      # Standard cassette path
      possible_paths << File.join(Rails.root, "test/vcr_cassettes", "#{name}.yml") 
      
      # Prompt cassette path (both with and without 'prompts/' prefix)
      clean_name = name.sub(/^prompts\//, '')
      possible_paths << File.join(Rails.root, "test/vcr_cassettes/prompts", "#{clean_name}.yml")
      
      # If name doesn't already have the subdirectory and it's a prompt cassette
      if prompt_cassette?(name) && !name.include?('/')
        possible_paths << File.join(Rails.root, "test/vcr_cassettes/prompts", "#{name}.yml")
      end
      
      # Try all possible paths
      found_path = possible_paths.find { |path| File.exist?(path) }
      
      found_path ? File.mtime(found_path) : nil 
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
        rescue => e
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
    
    # Extract just the request schema (for displaying input expectations)
    def extract_request_schema(cassette_data)
      return { has_schema: false } unless cassette_data
      
      if cassette_data["http_interactions"]
        extract_request_schema_from_http_interaction(cassette_data["http_interactions"].first)
      else
        extract_request_schema_from_direct_format(cassette_data)
      end
    end

    private
    
    def extract_request_schema_from_http_interaction(interaction)
      return { has_schema: false } unless interaction && 
                                        interaction["request"] && 
                                        interaction["request"]["body"] && 
                                        interaction["request"]["body"]["string"]

      result = {
        has_schema: false,
        schema: nil,
        schema_name: nil
      }

      begin
        req_body = JSON.parse(interaction["request"]["body"]["string"])
        
        # Response API format schema
        if req_body["text"] && req_body["text"]["format"] && req_body["text"]["format"]["schema"]
          result[:has_schema] = true
          result[:schema] = req_body["text"]["format"]["schema"]
          result[:schema_name] = req_body["text"]["format"]["name"] if req_body["text"]["format"]["name"]
        
        # Chat API format schema
        elsif req_body["response_format"] && req_body["response_format"]["json_schema"] && req_body["response_format"]["json_schema"]["schema"]
          result[:has_schema] = true
          result[:schema] = req_body["response_format"]["json_schema"]["schema"]
          result[:schema_name] = req_body["response_format"]["json_schema"]["name"] if req_body["response_format"]["json_schema"]["name"]
        end
      rescue
        # Failed to parse request body
      end
      
      result
    end
    
    def extract_request_schema_from_direct_format(cassette_data)
      result = {
        has_schema: false,
        schema: nil,
        schema_name: nil
      }
      
      if cassette_data["request"] && cassette_data["request"]["schema"]
        result[:has_schema] = true
        result[:schema] = cassette_data["request"]["schema"]
        result[:schema_name] = cassette_data["request"]["schema_name"] if cassette_data["request"]["schema_name"]
      end
      
      result
    end
    
    def extract_structured_data_from_http_interaction(interaction)
      return { has_structured_data: false } unless interaction && 
                                                  interaction["response"] && 
                                                  interaction["response"]["body"] && 
                                                  interaction["response"]["body"]["string"]

      result = {
        has_structured_data: false,
        structured_output: nil,
        schema: nil,
        response_string: interaction["response"]["body"]["string"]
      }

      begin
        json_response = JSON.parse(result[:response_string])
        
        # Check for direct structured_output or schema
        if json_response.is_a?(Hash) && (json_response["structured_output"].present? || json_response["schema"].present?)
          result[:has_structured_data] = true
          result[:structured_output] = json_response["structured_output"]
          result[:schema] = json_response["schema"]
        
        # Check for OpenAI responses API format
        elsif json_response.is_a?(Hash) && json_response["output"].is_a?(Array) && json_response["output"].first["content"].is_a?(Array)
          # Extract text content
          text_content = json_response["output"].first["content"].find { |content| content["type"] == "output_text" }
          
          if text_content && text_content["text"].present?
            begin
              # Try to parse the text as JSON (it often contains the structured output)
              parsed_text = JSON.parse(text_content["text"])
              if parsed_text.is_a?(Hash)
                result[:has_structured_data] = true
                result[:structured_output] = parsed_text
              end
            rescue
              # Not JSON, continue checking
            end
          end
        
        # Check for OpenAI chat completions API format
        elsif json_response.is_a?(Hash) && json_response["choices"].is_a?(Array) && json_response["choices"].first["message"].present?
          message_content = json_response["choices"].first["message"]["content"]
          if message_content.present?
            begin
              # Try to parse the content as JSON (for structured responses)
              parsed_content = JSON.parse(message_content)
              if parsed_content.is_a?(Hash)
                result[:has_structured_data] = true
                result[:structured_output] = parsed_content
              end
            rescue
              # Not JSON, continue checking
            end
          end
        end
        
        # Check request body for schema definition
        if interaction["request"] && interaction["request"]["body"] && interaction["request"]["body"]["string"]
          begin
            req_body = JSON.parse(interaction["request"]["body"]["string"])
            
            # Response API format schema
            if req_body["text"] && req_body["text"]["format"] && req_body["text"]["format"]["schema"]
              result[:has_structured_data] = true
              result[:schema] = req_body["text"]["format"]["schema"]
            
            # Chat API format schema
            elsif req_body["response_format"] && req_body["response_format"]["json_schema"] && req_body["response_format"]["json_schema"]["schema"]
              result[:has_structured_data] = true
              result[:schema] = req_body["response_format"]["json_schema"]["schema"]
            end
          rescue
            # Failed to parse request body
          end
        end
        
        result[:json_response] = json_response
      rescue
        # Failed to parse JSON
      end
      
      result
    end

    def extract_structured_data_from_direct_format(cassette_data)
      result = {
        has_structured_data: false,
        structured_output: nil,
        schema: nil
      }
      
      if cassette_data["response"]
        # Direct format
        if cassette_data["response"]["structured_output"].present?
          result[:has_structured_data] = true
          result[:structured_output] = cassette_data["response"]["structured_output"]
        end
        
        if cassette_data["response"]["schema"].present?
          result[:has_structured_data] = true
          result[:schema] = cassette_data["response"]["schema"]
        end
        
        result[:content] = cassette_data["response"]["content"]
      end
      
      result
    end
  end
end
