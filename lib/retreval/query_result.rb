require 'ostruct'

module Retreval
  
  
  # A QueryResultSet combines multiple QueryResults and stores them. It is possible to load
  # a set of QueryResults from a YAML file.
  class QueryResultSet
    
    attr_reader :query_results
    
    # Creates a new QueryResultSet, with a specified GoldStandard
    # Called by:
    #     QueryResultSet.new :gold_standard => my_gold_standard
    def initialize(args)
      @query_results = Array.new
      @gold_standard = args[:gold_standard]
      raise "Can not create a Query Result set without a gold standard that they belong to" if args[:gold_standard].nil?
    end
    
    # Parses a YAML file containing many result sets, either ranked or unranked.
    # The file should look like this:
    #     - query: Test query
    #       ranked: true
    #       documents:
    #           - id: first_document.txt
    #             score: 95
    #           - id: second_document.txt
    #             score: 38
    #     - query: Second query
    #       ranked: true
    #       documents:
    #           - id: another_doc.txt
    #             score: 12
    #           - id: yet_another_one.txt
    #             score: 1
    # ... and so on.
    def load_from_yaml_file(file)
      begin
        ydoc = YAML.load(File.open(file, "r"))
        ydoc.each do |entry|
          query = entry["query"]          # => the query string
          ranked = entry["ranked"]        # => a boolean flag if ranked or not
          documents = entry["documents"]  # => an array of documents
          
          # Determine whether this will be a ranked or unranked result set
          resultset = ranked ? RankedQueryResult.new : UnrankedQueryResult.new
          
          # Find all documents for this query result
          documents.each do |document_element|
            document = document_element["id"]
            score = document_element["score"]
            resultset.add_document :document => document, :score => score
          end
          
          @query_results << resultset
          
        end
      rescue Exception => e
        raise "Error while parsing the YAML document: " + e.message
      end
    end
    
    
    # Adds a QueryResult to the list of results for this set
    def add_result(result)
      @query_results << result
    end
    
    # Calculates the Mean Average Precision for each RankedQueryResult in this set.
    # This method should only be called when all sets have been calculated, or else it will
    # take a really long time to perform all necessary calculations.
    def mean_average_precision
      total_ranked_query_results = @query_results.count { |result| result.class == RankedQueryResult }
      @mean_average_precision = @query_results.inject(0.0) { |sum, result| result.class == RankedQueryResult ? sum + result.average_precision : sum } / total_ranked_query_results
    end
    
  end
  
  # A QueryResult contains a list of results for a given query. It can either be
  # ranked or unranked. You can't instantiate such a class - use the subclasses
  # RankedQueryResult and UnrankedQueryResult instead.
  class QueryResult
    
    attr_reader :query, :documents
    attr_accessor :gold_standard
    
    # Creates a new QueryResult with a specified query string and an optional array of documents.
    # This class is abstract, so you have to create an UnrankedQueryResult or a RankedQueryResult instead
    def initialize(args)
      
      if self.class == QueryResult
        raise "Can not instantiate a QueryResult. Use a RankedQueryResult or UnrankedQueryResult instead."
      end
      
      # Get the string of the query
      @query = Query.new :querystring => args[:query]
      raise "Can not create a Query Result without a query string specified" if args[:query].nil?
      
      # get the documents
      # documents is an array - each document contains a document (from the Class document) with a score
      # documents can also be omitted from the call and can be added later
      @documents = Array.new
      args[:documents].each { |document| add_document(document) } unless args[:documents].nil?
      
      # set the gold standard
      @gold_standard = args[:gold_standard]
      raise "Can not create a Query Result without a gold standard that it belongs to" if args[:gold_standard].nil?
      
    end
    
    
    # Loads Documents from a simple YAML file
    # Each entry should contain:
    # * "document"      The identifier of the Document
    # * "score"         The relevancy score for this Document
    def load_from_yaml_file(file)
      
      begin
        @ydoc = YAML::load(File.open(file, "r"))
        @ydoc.each do |entry|
          document = entry["document"]    # => the identifier of the document
          score = entry["score"]          # => the relevancy score
          add_document :document => document, :score => score
        end
        
      rescue Exception => e
        raise "Error while parsing the YAML document: " + e.message
      end
      
    end
    
    
    # Adds a single ResultDocument to the result
    # Call this with:
    #     add_document :document => "test_document", :score => 13
    # Alternatively:
    #     add_document :id => "test_document", :score => 13
    def add_document(args)
      document_id = args[:document]
      if document_id.nil?
        if args[:id].nil?
          raise "Can not add a new Document to a Query Result without a document identifier"
        else
          document_id = args[:id]
        end
      end
      
      doc = ResultDocument.new :id => document_id, :score => args[:score]
      @documents << doc
    end
    
    
    # This is essentially the same as add_document
    def <<(args)
      add_document args
    end
    
    
    # Prints a pretty contingency table summary
    def print_contingency_table
      results = calculate
      
      tp = results[:true_positives]
      fp = results[:false_positives]
      tn = results[:true_negatives]
      fn = results[:false_negatives]
      
      print "\t\t"
      print "| Relevant\t| Nonrelevant\t| Total\n"
      print "---------------------------------------------------------\n"
      print "Retrieved\t| " + tp.to_s + " \t\t| " + fp.to_s + " \t\t| " + (tp+fp).to_s + " \n"
      print "Not Retrieved\t| " + fn.to_s + " \t\t| " + tn.to_s + " \t\t| " + (fn+tn).to_s + " \n"
      print "---------------------------------------------------------\n"
      print "\t\t| " + (tp+fn).to_s + " \t\t| " + (fp+tn).to_s + " \t\t| " + (tp+fp+tn+fn).to_s + "\n"
      print "\n"
    end
    
    
    # Calculates the F-measure, weighing precision and recall.
    # See: http://nlp.stanford.edu/IR-book/html/htmledition/evaluation-of-unranked-retrieval-sets-1.html
    def f_measure(args = {:beta => 1})
      
      # Get intermediate results for both un/ranked results
      results = calculate
      
      precision = results[:precision]
      recall = results[:recall]
      
      begin
        # The user has the option to supply either alpha or beta (or both, doesn't matter)
        unless args[:alpha].nil?
          alpha = args[:alpha].to_f
          beta_squared = (1 - alpha) / alpha
        end
        
        unless args[:beta].nil?
          beta = args[:beta].to_f
          beta_squared = beta * beta
        end
        
        ((beta_squared + 1) * precision * recall) / ((beta_squared * precision) + recall)
        
      rescue Exception => e
        raise "Error while calculating F-Measure: " + e.message
      end
      
    end
    
    
    # Clean up every ResultDocument from this QueryResult that does not appear to have
    # a Judgement in the GoldStandard.
    def cleanup
      @documents.keep_if { |document| @gold_standard.contains_judgement? :document => document.id, :query => @query.querystring }
    end
    
    
    private
    
    # This is the method that performs all necessary calculations on a set of results.
    # Never call this. It should be called automatically.
    def calculate(resultset = nil)
      
      # Use the gold standard we initially received
      standard = @gold_standard
      
      if resultset.nil?
        unranked = true
        resultset = self
      end
      
      begin
        all_items = standard.documents.length               # => all documents this gold standard contains
        retrieved_items = resultset.documents.length        # => all items retrieved for this information need
        not_retrieved_items = all_items - retrieved_items   # => all items NOT retrieved for this information need
        retrieved_relevant_items = 0                        # => the count of retrieved and relevant documents
        not_retrieved_relevant_items = 0                    # => the count of nonretrieved relevant documents

        # Get the query we are working on
        query = resultset.query
      
        # Get the document sets we are working on
        retrieved_documents = resultset.documents
        not_retrieved_documents = standard.documents.reject { |doc| retrieved_documents.include? doc }
        
        # Check whether each of the retrieved documents is relevant or not ...
        retrieved_documents.each do |doc|
          relevant = standard.relevant? :document => doc.id, :query => query.querystring
          retrieved_relevant_items +=1 if relevant
        end
        retrieved_nonrelevant_items = retrieved_items - retrieved_relevant_items
        
        # ... do the same for nonretrieved documents
        not_retrieved_documents.each do |doc|
          relevant = standard.relevant? :document => doc.id, :query => query.querystring
          not_retrieved_relevant_items += 1 if relevant
        end
        not_retrieved_nonrelevant_items = not_retrieved_items - not_retrieved_relevant_items
      
        # Now calculate the sum counts
        relevant_items = retrieved_relevant_items + not_retrieved_relevant_items
        nonrelevant_items = retrieved_nonrelevant_items + not_retrieved_nonrelevant_items
      
        # Finally, calculate precision and recall
        precision = retrieved_relevant_items.to_f / retrieved_items.to_f
        if relevant_items != 0
          recall = retrieved_relevant_items.to_f / relevant_items.to_f
        else
          recall = 0
        end
        
        # This hash will be available as the result later
        results = {
          :precision => precision,
          :recall => recall,
          :false_negatives => not_retrieved_relevant_items,
          :false_positives => retrieved_nonrelevant_items,
          :true_negatives => not_retrieved_nonrelevant_items,
          :true_positives => retrieved_relevant_items
        }
        
        # Also, if we're doing a ranked evaluation, we want to find out if the
        # newly added document is relevant (thus increasing precision and recall)
        unless unranked
          results[:document] = retrieved_documents.last.id
          results[:relevant] = standard.relevant? :document => results[:document], :query => query.querystring
        end
        
        results
        
      end
    end
  end
  
  
  
  # A RankedQueryResult is a QueryResult with special functions 
  # for ranked retrieval evaluation.
  class RankedQueryResult < QueryResult

    # Creates a new RankedQueryResult. One has to specify the query string and can
    # optionally pass a Document array too. The rank of the Document will be defined by
    # its position in the array only.
    # Called by:
    #     RankedQueryResult.new :documents => array_of_document_ids, :query => "my query"
    #     RankedQueryResult.new :query => "my query"
    def initialize(args)
      super(args)
    end
    
    
    # Calculates the 11-point precision and the average interpolated precision.
    # See: http://nlp.stanford.edu/IR-book/html/htmledition/evaluation-of-ranked-retrieval-results-1.html
    def eleven_point_precision
      
      statistics unless @calculated

      @recall_levels = Hash.new

      # Find out what recall/precision pairs we already know
      @results.each_with_index do |row, index|
        precision = row[:precision]
        recall = row[:recall]
        @recall_levels[recall] = precision
      end

      begin
        @eleven_point_precision = Hash.new

        # Calculate the 11 points
        # This outer loop effectively iterates from 0.0 to 1.0
        (0..10).each_with_index do |recall_level, index|
          recall_level = recall_level.to_f / 10
          @eleven_point_precision[recall_level] = 0

          # Look in our known recall levels (stored as the keys)
          @recall_levels.keys.each do |key|
            
            # If we find a known recall equal or higher to the one from the 11-point
            # scale, return the precision at that level
            # E.g. if our level is 0.3 and we have a known precision at 0.5, this
            # one will be used as our interpolated precision
            if key >= recall_level
              precision_for_level = @recall_levels[key]
              # Store the interpolated precision at the current level, e.g. 0.3
              @eleven_point_precision[recall_level] = precision_for_level
              break
            end
          end
        end

        # Now calculate an average precision for this statistic
        # That's a neat line of ruby code, is it?
        @eleven_point_average = @eleven_point_precision.values.inject(0.0) { |sum, precision| sum + precision } / 11
        
      rescue
        raise "Error while calculating the 11-point precision map!"
      end

      @eleven_point_precision
      
    end
    
    
    # Calculates the precision and recall for each rank and returns
    # it in a Hash of results
    def statistics(max = 0)
      
      return @results if @calculated
      
      begin
      
        # If no maximum parameter is given, all documents are evalutated
        # This should be the default for normal evaluations
        max = @documents.length if max == 0 or max > @documents.length
      
        # Calculate precision and recall for the top i documents only
        @results = Array.new
        for i in (1..max)
          subset = OpenStruct.new
          subset.documents = Array.new
          subset.query = @query
          @documents.each_with_index do |doc, index|
            # Only get the subset of documents
            subset.documents << doc
            break if index == i - 1
          end
          results = calculate(subset)
          @results << results
        end
      
        # Now mark everything as calculated and return it
        @calculated = true
        @results
      
      rescue Exception => e
        raise "Error while calculating results: " + e.message
      end
      
    end
    
    
    # Returns the average precision. It is the average of precisions computed at 
    # the point of each of the relevant documents in the ranked sequence.
    def average_precision
      begin
        # Calculate the results first if we haven't done this before
        statistics unless @calculated
        
        total_relevant_documents = @gold_standard.documents.count { |doc| @gold_standard.relevant? :document => doc.id, :query => @query.querystring  }
        
        if total_relevant_documents > 0
          # The sum is calculated by adding the precision for a relevant document, or 0 for a nonrelevant document
          return @average_precision = @results.inject(0.0) { |sum, document| document[:relevant] ? document[:precision] + sum : sum } / total_relevant_documents
        else
          return @average_precision = 0
        end
      rescue Exception => e
        raise "Error while calculating average precision: " + e.message
      end
      
    end
    
    
    # Prints a pretty table for 11-point interpolated precision
    def print_eleven_point_precision_table
      
      # Calculate the results first if we haven't done this before
      statistics unless @calculated
      
      data = eleven_point_precision
      print "Recall\tInterpolated Precision\n"
      data.each_pair do |recall, precision|
        print recall.to_s + "\t" + "%.3f" % precision + "\n"
      end
      print "--------------------------------------\n"
      print "Avg.\t" + "%.3f" % @eleven_point_average + "\n"
      print "\n"
      
    end
    
    
    # Prints a pretty table for ranked results
    def print_ranked_table
      
      # Calculate the results first if we haven't done this before
      statistics unless @calculated
            
      # Use the results to print a table
      print "Query: #{@query}\n"
      print "Index\tRelevant\tPrecision\tRecall\tScore\t\tDocument ID\n"
      @results.each_with_index do |row, index|
        precision = "%.3f" % row[:precision]
        document = @documents[index].id
        recall = "%.3f" %  row[:recall]
        relevant = row[:relevant] ? "[X]" : "[ ]"
        print "#{index+1}\t" + relevant + "\t\t" + precision + "\t\t" + recall + "\t" + @documents[index].score.to_s + "\t" + document + "\n"
      end
      print "\n"
      
    end
    
  end
  
  
  
  # An UnrankedQueryResult is a QueryResult with no special functions.
  class UnrankedQueryResult < QueryResult
    
    # Creates a new RankedQueryResult. One has to specify the query string and can
    # optionally pass a Document array too.
    # Called by:
    #     QueryResult.new :documents => array_of_document_ids, :query => "my query"
    #     QueryResult.new :query => "my query"
    def initialize(args)
      super(args)
    end
    
    # Calculates precision and recall and returns them in a Hash
    def statistics
      @calculated ? @results : calculate
    end
    
  end
  
  
  # A ResultDocument, in contrast to a Document, can also have a 
  # score that was determined to compute its rank in an information need.
  # The score will only be output for informational purposes.
  class ResultDocument < Document
    
    attr_reader :score
    
    # Creates a new ResultDocument    
    def initialize(args)
      super(args)
      @score = args[:score]
    end
    
  end
  
end