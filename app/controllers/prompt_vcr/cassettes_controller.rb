require "fileutils"

module PromptVCR
  class CassettesController < ApplicationController
    layout "prompt_vcr/application"

    def index
      # Get all cassettes and categorize by content
      filter_type = params[:type] || "all"

      # Get the full list of cassettes
      cassettes = cassette_parser.list_cassettes

      # Categorize by content - examine each cassette to determine if it contains prompts
      @all_cassettes = []
      @cassette_metadata = {}

      cassettes.each do |cassette|
        # Load the cassette data
        data = cassette_parser.load_cassette(cassette)
        next unless data

        # Extract basic metadata
        metadata = cassette_parser.extract_metadata(data, cassette)
        @cassette_metadata[cassette] = metadata

        # Determine if this cassette contains prompt and/or standard requests
        has_prompts = false
        has_standard = false
        
        # Check HTTP interactions if present
        if data["http_interactions"].present?
          # For http_interactions, check each interaction type
          data["http_interactions"].each do |interaction|
            if cassette_parser.is_prompt_interaction?(interaction)
              has_prompts = true
            else
              has_standard = true
            end
            # If we've found both types, we can stop checking
            break if has_prompts && has_standard
          end
        else
          # For non-HTTP cassettes, check if it looks like a prompt
          has_prompts = cassette_parser.contains_prompt_interaction?(data)
          has_standard = !has_prompts # If not a prompt, it's standard
        end

        # Add to the list with categorization
        @all_cassettes << {
          name: cassette,
          has_prompts: has_prompts,
          has_standard: has_standard,
          is_mixed: has_prompts && has_standard,
          metadata: metadata
        }
      end

      # Apply filtering if requested
      case filter_type
      when "prompts"
        @filtered_cassettes = @all_cassettes.select { |c| c[:has_prompts] && !c[:has_standard] }
      when "standard"
        @filtered_cassettes = @all_cassettes.select { |c| c[:has_standard] && !c[:has_prompts] }
      when "mixed"
        @filtered_cassettes = @all_cassettes.select { |c| c[:is_mixed] }
      else
        @filtered_cassettes = @all_cassettes
      end
    end

    def show
      @cassette_name = params[:id]

      # Add debug logging
      Rails.logger.info "Loading cassette: #{@cassette_name}"

      # Load the cassette data using our single parser
      @cassette_data = cassette_parser.load_cassette(@cassette_name)

      if @cassette_data.nil?
        Rails.logger.error "Failed to load cassette data for: #{@cassette_name}"
        redirect_to cassettes_path, alert: "Cassette '#{@cassette_name}' not found"
        return
      else
        Rails.logger.info "Successfully loaded cassette data with keys: #{@cassette_data.keys}"
      end

      # Get file metadata
      @file_metadata = {
        created_at: cassette_parser.file_created_at(@cassette_name),
        updated_at: cassette_parser.file_updated_at(@cassette_name)
      }

      # Process HTTP interactions if present
      if @cassette_data["http_interactions"].present?
        # Extract and categorize individual interactions
        @interactions = []

        @cassette_data["http_interactions"].each_with_index do |interaction, index|
          # Check if this specific interaction is a prompt using our parser helper
          is_prompt = cassette_parser.is_prompt_interaction?(interaction)

          # Extract structured data and schema
          structured_data = {}
          request_schema = {}

          if is_prompt
            # This interaction is a prompt, extract more detailed info
            structured_data = cassette_parser.extract_structured_data_from_http_interaction(interaction)
            request_schema = cassette_parser.extract_request_schema_from_http_interaction(interaction)
          end

          @interactions << {
            index: index,
            is_prompt: is_prompt,
            request: interaction["request"],
            response: interaction["response"],
            structured_data: structured_data,
            request_schema: request_schema,
            recorded_at: interaction["recorded_at"]
          }
        end

        # Determine if the cassette is primarily a prompt cassette
        prompt_count = @interactions.count { |i| i[:is_prompt] }
        @is_prompt_cassette = prompt_count > 0
        @has_mixed_requests = prompt_count > 0 && prompt_count < @interactions.size

        # Set the viewed interaction index from query params or default to the first
        @interaction_index = params[:interaction].present? ? params[:interaction].to_i : 0

        # If they're looking for a prompt and none is selected, find the first prompt interaction
        if params[:type] == "prompt" && @interaction_index == 0
          prompt_interaction = @interactions.find { |i| i[:is_prompt] }
          @interaction_index = @interactions.index(prompt_interaction) if prompt_interaction
        end

        # Current interaction for display
        @current_interaction = @interactions[@interaction_index] || @interactions.first
        
        # Make structured data and schema available for the template
        if @current_interaction
          @structured_data = @current_interaction[:structured_data]
          @request_schema = @current_interaction[:request_schema]
        end

      else
        # Direct format (not HTTP interactions)
        @is_prompt_cassette = cassette_parser.contains_prompt_interaction?(@cassette_data)

        if @is_prompt_cassette
          @structured_data = cassette_parser.extract_structured_data(@cassette_data)
          @request_schema = cassette_parser.extract_request_schema(@cassette_data)
        else
          @structured_data = { has_structured_data: false }
          @request_schema = { has_schema: false }
        end

        # No interactions to navigate
        @interactions = []
        @interaction_index = 0
      end

      # Log detection results
      Rails.logger.info "Detected #{@interactions.size} interactions with #{@interactions.count { |i| i[:is_prompt] }} prompt requests"
    end

    def destroy
      @cassette_name = params[:id]

      # Attempt to delete the cassette
      if cassette_parser.delete_cassette(@cassette_name)
        redirect_to cassettes_path, notice: "Cassette '#{@cassette_name}' was successfully deleted."
      else
        redirect_to cassette_path(@cassette_name), alert: "Failed to delete cassette '#{@cassette_name}'."
      end
    end

    private

    def cassette_parser
      @cassette_parser ||= CassetteParser.new
    end
  end
end
