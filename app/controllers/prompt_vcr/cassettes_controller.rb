require 'fileutils'

module PromptVcr
  class CassettesController < ApplicationController
    layout "prompt_vcr/application"

    def index
      # Filter cassettes based on selected tab
      cassette_type = params[:type] || 'prompts'
      
      if cassette_type == 'all'
        # Get all cassettes but separate by type
        @cassette_groups = all_parser.list_cassettes_by_type
      else
        # Only show one type (prompts or standard)
        @cassette_groups = {}
        @cassette_groups[:prompts] = prompts_parser.list_cassettes if cassette_type == 'prompts'
        if cassette_type == 'standard'
          # Get all cassettes and filter out prompt cassettes manually
          all_cassettes = standard_parser.list_cassettes
          @cassette_groups[:others] = all_cassettes.reject { |cassette| standard_parser.prompt_cassette?(cassette) }
        end
      end
      
      @cassette_metadata = {}
      
      # Pre-load metadata for all prompt cassettes
      if @cassette_groups[:prompts].present?
        @cassette_groups[:prompts].each do |cassette|
          data = prompts_parser.load_cassette(cassette)
          @cassette_metadata[cassette] = prompts_parser.extract_metadata(data, cassette)
        end
      end
      
      # Pre-load basic metadata for other cassettes
      if @cassette_groups[:others].present?
        @cassette_groups[:others].each do |cassette|
          data = standard_parser.load_cassette(cassette)
          @cassette_metadata[cassette] = standard_parser.extract_metadata(data, cassette)
        end
      end
    end

    def show
      @cassette_name = params[:id]
      
      # Add debug logging
      Rails.logger.info "Loading cassette: #{@cassette_name}"
      
      # Determine if this is a prompt cassette
      # First check the explicit parameter
      @is_prompt_cassette = if params[:cassette_type].present?
                             params[:cassette_type] == 'prompt'
                           else
                             # Fall back to path-based detection
                             @cassette_name.include?(CassetteParser::PROMPTS_DIR) || 
                             @cassette_name.include?(CassetteParser::PROMPTS_DIR.singularize)
                           end
      
      Rails.logger.info "Cassette type param: #{params[:cassette_type]}, Is prompt cassette? #{@is_prompt_cassette}"
      
      Rails.logger.info "Is prompt cassette? #{@is_prompt_cassette}"
      
      if @is_prompt_cassette
        appropriate_parser = prompts_parser
        Rails.logger.info "Using prompts parser with base dir: #{appropriate_parser.base_dir}"
      else
        appropriate_parser = standard_parser
        Rails.logger.info "Using standard parser with base dir: #{appropriate_parser.base_dir}"
      end
      
      # Load the cassette data
      @cassette_data = appropriate_parser.load_cassette(@cassette_name)
      
      if @cassette_data.nil?
        Rails.logger.error "Failed to load cassette data for: #{@cassette_name}"
      else
        Rails.logger.info "Successfully loaded cassette data with keys: #{@cassette_data.keys}"
      end
      
      @file_metadata = {
        created_at: appropriate_parser.file_created_at(@cassette_name),
        updated_at: appropriate_parser.file_updated_at(@cassette_name)
      }
      
      # Type information already determined above
      
      if @is_prompt_cassette
        # Extract structured data information (only for prompt cassettes)
        @structured_data = appropriate_parser.extract_structured_data(@cassette_data)
        
        # Extract request schema information (only for prompt cassettes)
        @request_schema = appropriate_parser.extract_request_schema(@cassette_data)
      else
        # Basic info for regular cassettes
        @structured_data = { has_structured_data: false }
        @request_schema = { has_schema: false }
      end
    end

    private
    
    def prompts_parser
      @prompts_parser ||= CassetteParser.new(nil, :prompts)
    end
    
    def standard_parser
      @standard_parser ||= CassetteParser.new(Rails.root.join("test/vcr_cassettes"), :all)
    end
    
    def all_parser
      @all_parser ||= CassetteParser.new(Rails.root.join("test/vcr_cassettes"), :all)
    end
    
    def determine_parser_for_cassette(cassette_name)
      if cassette_name.include?(CassetteParser::PROMPTS_DIR) || 
         cassette_name.include?(CassetteParser::PROMPTS_DIR.singularize)
        prompts_parser
      else
        standard_parser
      end
    end
  end
end
