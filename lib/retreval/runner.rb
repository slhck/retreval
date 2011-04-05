require_relative 'options'
require_relative 'gold_standard'
require_relative 'query_result'
require 'yaml'
require 'pp'

# The Retreval allows to load and define Gold Standards, add Query Results and 
# calculate the most common metrics used in information retrieval evaluation.
module Retreval
  
  # A simple class that performs the task of running this library when called
  # from the commandline
  class Runner
    
    # Invokes a new Runner object by loading the options from the commandline
    def initialize(args)
      @options = Options.new(args)
    end
    
    # Takes the passed options for a GoldStandard file and loads it according to the format specified
    def load_gold_standard
      unless @options.gold_standard_file.nil?
        
          
        print "Loading gold standard file '#{@options.gold_standard_file}' ... " if $verbose
        @gold_standard = GoldStandard.new
        case @options.format
        when "yaml"
          @gold_standard.load_from_yaml_file @options.gold_standard_file
        when "plain"
          @gold_standard.load_from_plaintext_file @options.gold_standard_file
        else
          raise "I don't understand the format '#{@options.format}'"
        end
        
        print "done\n" if $verbose
        print "Gold standard loaded from #{@options.gold_standard_file} contains:
          - #{@gold_standard.queries.count} queries, 
          - #{@gold_standard.documents.count} documents,
          - #{@gold_standard.judgements.count} judgements, made by
          - #{@gold_standard.users.count} users\n\n" if $verbose        
      end
    end
    
    # Takes the passed options for a QueryResultSet file and loads it according to the format specified
    def load_query_result_set
      unless @options.query_result_set_file.nil?
          
        print "Loading query result set from file '#{@options.query_result_set_file}' ... " if $verbose
        @query_result_set = QueryResultSet.new :gold_standard => @gold_standard
        case @options.format
        when "yaml"
          @query_result_set.load_from_yaml_file @options.query_result_set_file
        when "plain"
          @query_result_set.load_from_yaml_file @options.query_result_set_file
        else
          raise "I don't understand the format '#{@options.format}'"
        end
        
        print "done\n" if $verbose
        print "Query results loaded from #{@options.query_result_set_file} contain:
          - #{@query_result_set.query_results.count} query results\n\n" if $verbose
      end
    end
    
    # Performs the default calculations and writes their output to the file specified
    def begin_calculations
      @statistics = Hash.new
      @average_precision = Hash.new
      
      @query_result_set.query_results.each_with_index do |result, index|
        begin
          print "Cleaning up results and removing documents without judgements ... \n" if $verbose
          result.cleanup
          
          print "Calculating statistics for result #{index+1} of #{@query_result_set.query_results.count} ... "
          @statistics[result.query.querystring] = result.statistics
          @average_precision[result.query.querystring] = result.average_precision
          print "Done.\n"
          
          result.print_ranked_table if $verbose          
          
          write_to_yaml_file :data => @statistics, :filename => "statistics.yml"
          write_to_yaml_file :data => @average_precision, :filename => "avg_precision.yml"
          
        # rescue Exception => e
        #  raise "Error while calculating results: #{e}"
        end
      end
      
      print "Finished calculating all results. Exiting.\n" if $verbose
      print "The mean average precision was #{@query_result_set.mean_average_precision}\n" if $verbose
      exit
      
    end
    
    # Writes an object to a YAML file.
    # Called by:
    #     write_to_yaml_file :data => my_data, :filename => "my_data_file.yml"
    def write_to_yaml_file(args)
      data = args[:data]
      filename = args[:filename]
      
      if data.nil? or filename.nil? 
        raise "Must pass filename and data in order to write to file!"
      end
      
      filename = @options.output + "_" + filename
      File.open(filename, "w") { |f| f.write data.to_yaml }
    end
    
    # Called when the script is executed from the command line
    def run
      
      load_gold_standard
      load_query_result_set
      begin_calculations
      
    end
  end
end