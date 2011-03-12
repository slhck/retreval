require 'optparse'
require 'ostruct'

module Retreval
  
  # Some options that can be passed when the script is run from the commandline
  class Options
    
    attr_accessor :query_result_set_file, :gold_standard_file, :format, :interactive, :output
    
    # Just initialize the OptionParser and try to parse the arguments
    def initialize(args)
      parse(args)
    end
    
    private
    
      # Parse the arguments that were passed
      def parse(args)
        OptionParser.new do |opts|
          opts.banner = "Usage: retreval [options]"
          opts.separator "Mandatory options (choose one):"
          
          opts.on("-l", "--load <gold-standard-file>", "Load the gold standard from this file") do |file|
            @gold_standard_file = file
          end
          
          opts.on("-q", "--queries <query-results-file>", "Load the query result set from this file") do |file|
            @query_result_set_file = file
          end
          
          opts.on("-f", "--format <format>", "Use this data format when parsing files. Can be one of <yaml|plain>") do |format|
            @format = format
          end
          
          opts.on("-o", "--output <output-file-prefix>", "Use this prefix for creating output files, default is 'output'.") do |file|
            @output = file
          end
          
          opts.separator "Common options:"
          
          opts.on_tail("-v", "--verbose", "Verbose (debug) mode") do
            $verbose = true
          end
          
          opts.on_tail("-h", "--help", "Show this message") do
            puts opts
            exit
          end
          
          begin
            args = ["-h"] if args.empty?
            opts.parse!(args)
            
            # Make some default assumptions
            @output = "output" if @output.nil?
            
          rescue OptionParser::ParseError => e
            STDERR.puts e.message, "\n", opts
            exit(-1)
          end
          
        end # opts
      end # self.parse
  end # Class options
end # module