module Retreval

  # A gold standard is composed of several judgements for the 
  # cartesian product of documents and queries
  class GoldStandard
    
    attr_reader :documents, :judgements, :queries, :users
    
    # Creates a new gold standard. One can optionally construct the gold
    # standard with triples given. This would be a hash like:
    #     triples = { 
    #        :document => "Document ID", 
    #        :query => "Some query", 
    #        :relevant => "true" 
    #      }
    # 
    # Called via:
    #     GoldStandard.new :triples => an_array_of_triples
    def initialize(args = {})
      @documents = Array.new
      @queries = Array.new
      @judgements = Array.new
      @users = Hash.new
      
      # one can also construct a Gold Standard with everything already loaded
      unless args[:triples].nil?
        args[:triples].each do |triple|
          add_judgement(triple)
        end
      end
    end
    
        
    # Parses a YAML file adhering to the following generic standard:
    # 
    # * "query"       denotes the query
    # * "documents"   these are the documents judged for this query
    # * "id"          the ID of the document (e.g. its filename, etc.)
    # * "judgements"  an array of judgements, each one with:
    # * "relevant"    a boolean value of the judgment (relevant or not)
    # * "user"        an optional identifier of the user
    #
    # Example file:
    #     - query: 12th air force germany 1957
    #       documents:
    #       - id: g5701s.ict21311
    #         judgements: []
    # 
    #       - id: g5701s.ict21313
    #         judgements: 
    #         - relevant: false
    #           user: 2
    def load_from_yaml_file(file)
      begin
        ydoc = YAML.load(File.open(file, "r"))
        ydoc.each do |entry|

          # The query is first in the hierarchy
          query = entry["query"]

          # Every query contains several documents
          documents = entry["documents"]
          documents.each do |doc|
            
            document = doc["id"]
            
            # Only count the map if it has judgements
            if doc["judgements"].empty?  
              add_judgement :document => document, :query => query, :relevant => nil, :user => nil
            else
              doc["judgements"].each do |judgement|
                relevant = judgement["relevant"]
                user = judgement["user"]
                
                add_judgement :document => document, :query => query, :relevant => relevant, :user => user
                
              end
            end
            
          end
        end

      rescue Exception => e
        raise "Error while parsing the YAML document: " + e.message
      end
    end
    
    
    # Parses a plaintext file adhering to the following standard:
    # Every line of text should include a triple that designates the judgement.
    # The symbols should be separated by a tabulator.
    # E.g.
    #   my_query        my_document_1     false
    #   my_query        my_document_2     true
    #
    # You can also add the user's ID in the fourth column.
    def load_from_plaintext_file(file)
      begin
        File.open(file).each do |line|
          line.chomp!
          info = line.split("\t")
          if info.length == 3
            add_judgement :query => info[0], :document => info[1], :relevant => info[2]
          elsif info.length == 4
            add_judgement :query => info[0], :document => info[1], :relevant => info[2], :user => info[3]
          end
        end
      rescue Exception => e
        raise "Error while parsing the document: " + e.message
      end
    end
    
    
    # Adds a judgement (document, query, relevancy) to the gold standard.
    # All of those are strings in the public interface.
    # The user ID is an optional parameter that can be used to measure kappa later.
    # Call this with:
    #     add_judgement :document => doc_id, :query => query_string, :relevant => boolean, :user => John
    def add_judgement(args)
      document_id = args[:document]
      query_string = args[:query]
      relevant = args[:relevant]
      user_id = args[:user]
      
      
      unless document_id.nil? or query_string.nil?
        document = Document.new :id => document_id
        query = Query.new :querystring => query_string
        
        
        # If the user exists, load it, otherwise create a new one
        if @users.has_key?(user_id)
          user = @users[user_id]
        else
          user = User.new :id => user_id unless user_id.nil?
        end
        
        # If there is no judgement for this combination, just add the document/query pair
        if relevant.nil?
          # TODO: improve efficiency by introducing hashes !
          @documents << document unless @documents.include?(document)
          @queries << query unless @queries.include?(query)
          return
        end
        
        if user_id.nil?
          judgement = Judgement.new :document => document, :query => query, :relevant => relevant
        else
          judgement = Judgement.new :document => document, :query => query, :relevant => relevant, :user => user
          
          user.add_judgement(judgement)
          @users[user_id] = user
        end
        
        @documents << document unless @documents.include?(document)
        @queries << query unless @queries.include?(query)
        @judgements << judgement
      else
        #TOOD I think there is somethink like an ArgumentExcpetion in Ruby; use that if applicable
        raise "Need at least a Document, and a Query for creating the new entry."
      end
      
    end
    
    # This is essentially the same as adding a Judgement, we can use this operator too.
    def <<(args)
      self.add_judgement args
    end
    
    # Returns true if a Document is relevant for a Query, according to this GoldStandard.
    # Called by:
    #     relevant? :document => "document ID", :query => "query"
    def relevant?(args)
      query = Query.new :querystring => args[:query]
      document = Document.new :id => args[:document]
      
      relevant_count = 0
      nonrelevant_count = 0
      
      #TODO: looks quite inefficient. Would a hash with document-query-pairs as key help?
      @judgements.each do |judgement|
        if judgement.document == document and judgement.query == query
          judgement.relevant ? relevant_count += 1 : nonrelevant_count += 1
        end
      end
      
      # If we didn't find any judgements, just leave it as false
      if relevant_count == 0 and relevant_count == 0
        false
      else
        relevant_count >= nonrelevant_count
      end
    end
    
    
    # Returns true if this GoldStandard contains a Judgement for this Query / Document pair
    # This is called by:
    #     contains_judgement? :id => "the document ID", :querystring => "the query"
    def contains_judgement?(args)
      query = Query.new :querystring => args[:query]
      document = Document.new :id => args[:document]
      
      #TODO: a hash could improve performance here as well
      
      @judgements.each { |judgement| return true if judgement.document == document and judgement.query == query }
      
      false
    end
    
    
    # Returns true if this GoldStandard contains this Document
    # Called by:
    #     contains_document? :id => "document ID"
    def contains_document?(args)
      document_id = args[:id]
      document = Document.new :id => document_id
      @documents.include? document
    end
    
    
    # Returns true if this GoldStandard contains this Query string
    # Called by:
    #     contains_query? :querystring => "the query"
    def contains_query?(args)
      querystring = args[:querystring]
      query = Query.new :querystring => querystring
      @queries.include? query
    end
    
    
    # Returns true if this GoldStandard contains this User
    # Called by:
    #     contains_user? :id => "John Doe"
    def contains_user?(args)
      user_id = args[:id]
      @users.key? user_id
    end
    
    
    # Calculates and returns the Kappa measure for this GoldStandard. It shows
    # to which degree the judges agree in their decisions
    # See: http://nlp.stanford.edu/IR-book/html/htmledition/assessing-relevance-1.html
    def kappa
      
      # FIXME: This isn't very pretty, maybe there's a more ruby-esque way to do this?
      sum = 0
      count = 0
      
      # A repeated_combination yields all the pairwise combinations of
      # users to generate the pairwise kappa statistic. Elements are also
      # paired with themselves, so we need to remove those.
      @users.values.repeated_combination(2) do |combination|
        user1, user2 = combination[0], combination[1]
        unless user1 == user2
          kappa = pairwise_kappa(user1, user2)
          unless kappa.nil?
            puts "Kappa for User #{user1.id} and #{user2.id}: #{kappa}" if $verbose
            sum += kappa unless kappa.nil?
            count += 1
          end
        end
      end
      
      @kappa = sum / count.to_f
      puts "Average pairwise kappa: #{@kappa}" if $verbose
      return @kappa
    end
    
    private
    
    # Calculates the pairwise kappa statistic for two users.
    # The two users objects need at least one Judgement in common.
    # Note that the kappa statistic is not really meaningful when there are
    # too little judgements in common!
    def pairwise_kappa(user1, user2)
      
      user1_judgements = user1.judgements.reject { |judgement| not user2.judgements.include?(judgement) }
      user2_judgements = user2.judgements.reject { |judgement| not user1.judgements.include?(judgement) }
      
      total_count = user1_judgements.count
      
      unless user1_judgements.empty? or user1_judgements.empty?
        
        positive_agreements = 0     # => when both judges agree positively (relevant)
        negative_agreements = 0     # => when both judges agree negatively (nonrelevant)
        negative_disagreements = 0  # => when the second judge disagrees by using "nonrelevant"
        positive_disagreements = 0  # => when the second judge disagrees by using "relevant"
        
        for i in 0..(user1_judgements.count-1)
          if user1_judgements[i].relevant == true
            if user2_judgements[i].relevant == true
              positive_agreements += 1
            else
              negative_disagreements += 1
            end
          elsif user1_judgements[i].relevant == false
            if user2_judgements[i].relevant == false
              negative_agreements += 1
            else
              positive_disagreements += 1
            end
          end
        end
        
        # The proportion the judges agreed:
        p_agreed = (positive_agreements + negative_agreements) / total_count.to_f
        
        # The pooled marginals:
        p_nonrelevant = (positive_disagreements + negative_agreements * 2 + negative_disagreements) / (total_count.to_f * 2)
        # This one is the opposite of P(nonrelevant):
        # p_relevant = (positive_agreements * 2 + negative_disagreements + positive_disagreements) / (total_count.to_f * 2)
        p_relevant = 1 - p_nonrelevant
        
        # The probability that the judges agreed by chance
        p_agreement_by_chance = p_nonrelevant ** 2 + p_relevant ** 2
        
        
        # Finally, the pairwise kappa value
        # If there'd be a division by zero, we avoid it and return 0 right away
        if p_agreed - p_agreement_by_chance == 0
          return 0
        # In any other case, the kappa value is correct and we can return it
        else
          kappa = (p_agreed - p_agreement_by_chance) / (1 - p_agreement_by_chance)
          return kappa
        end
      end
      
      # If there are no common judgements, there is no kappa value to calculate
      return nil
    end
    
  end
  
  
  # A Query is effectively a string that is used as its ID.
  class Query
    
    attr_reader :querystring
    
    # Compares two Query objects according to their query string
    def ==(query)
      query.querystring == self.querystring
    end

    # Creates a new Query object with a specified string    
    def initialize(args)
      @querystring = args[:querystring].to_s
      raise "Can not construct a Query with an empty query string" if @querystring.nil?
    end
    
  end
  
  # A Document is a generic resource that is identified by its ID (which could be anything).
  class Document
    
    attr_reader :id

    # Compares two Document objects according to their id
    def ==(document)
      document.id == self.id
    end

    # Creates a new Document object with a specified id    
    def initialize(args)
      @id = args[:id].to_s
      raise "Can not construct a Document with an empty identifier" if @id.nil?
    end
    
  end
  
  # A Judgement references one query and one document as being relevant to each other or not.
  # It also keeps track of the User who created the Judgement, if necessary.
  class Judgement
    
    attr_reader :relevant, :document, :query, :user

    # Creates a new Judgement that belongs to a Query, a Document, and optionally to a User
    # Called by (note the usage of IDs, not objects):
    #     Judgement.new :document => my_doc_id, :user => my_user_id, :query => query_string, :relevant => true
    def initialize(args)
      @relevant = args[:relevant]
      @document = args[:document]
      @query = args[:query]
      @user = args[:user]
    end
    
    
    # A Judgement is considered equal to another when they are for the same Query or Document.
    # This comparison happens regardless of the user, so it is easier to generate "unique" Judgements
    # or calculate the kappa measure.
    def ==(judgement)
      self.document == judgement.document and self.query == judgement.query
    end
    
  end
  
  # A User is optional for a Judgement, they are identified by their ID, which could be anything.
  class User
    
    attr_reader :id, :judgements
    
    # Compares two User objects according to their id
    def ==(user)
      user.id == self.id
    end
    
    
    # Creates a new User object with a specified id
    def initialize(args)
      @id = args[:id]
      @judgements = Array.new
      raise "Can not construct a User with an empty identifier" if @id.nil? 
    end
    
    
    # Adds a reference to a Judgement to this User object, since this makes it 
    # easier to calculate kappa later. Some users have multiple judgements for
    # the same Document Query pair, which isn't really helpful. We therefore eliminate
    # duplicates.
    def add_judgement(judgement)
      @judgements << judgement unless @judgements.include?(judgement)
    end
    
  end
end