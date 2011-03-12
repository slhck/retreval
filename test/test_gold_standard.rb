require 'test/unit'
require 'retrievalAPI/gold_standard'

# Some basic unit tests for the GoldStandard
class TestGoldStandard < Test::Unit::TestCase 
  
  
  # Adds one test judgement to this test case
  def add_test_judgement
    @gold_standard = Retreval::GoldStandard.new
    @gold_standard.add_judgement :document => "doc1", :query => "query1", :relevant => true, :user => "John Doe"
  end
  
  
  # Tests whether the Document is correctly included
  def test_document
    add_test_judgement
    assert(@gold_standard.contains_document? :id => "doc1")
  end
  
  
  # Tests whether the Query is correctly included
  def test_query
    add_test_judgement
    assert(@gold_standard.contains_query? :querystring => "query1")
  end
  
  
  # Tests whether the User is correctly included
  def test_user
    add_test_judgement
    assert(@gold_standard.contains_user? :id => "John Doe")
  end
  
  
  # Tests whether the Judgement is correctly included
  def test_judgement
    add_test_judgement
    assert(@gold_standard.contains_judgement? :document => "doc1", :query => "query1")
  end
  
  
  # Tests whether the Judgement (i.e. the relevancy) is correctly added
  def test_relevant
    add_test_judgement
    assert(@gold_standard.relevant? :document => "doc1", :query => "query1")
  end
  
  # Tests if the kappa measure is calculated correctly.
  # See http://nlp.stanford.edu/IR-book/html/htmledition/assessing-relevance-1.html
  # for the examples in this test
  def test_kappa_ir_book
    
    @gold_standard = Retreval::GoldStandard.new
    
    for i in (1..300) do 
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Alice", :relevant => true
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Bob", :relevant => true
    end
    
    for i in (301..320) do
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Alice", :relevant => true
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Bob", :relevant => false
    end
    
    for i in (321..330) do
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Alice", :relevant => false
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Bob", :relevant => true
    end
    
    for i in (331..400) do
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Alice", :relevant => false
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Bob", :relevant => false
    end
    
    assert_equal(0.7759103641456584, @gold_standard.kappa, "IR Book kappa test failed!")
  end
  
  
  # Tests if the kappa measure is calculated correctly.
  # See http://nlp.stanford.edu/IR-book/html/htmledition/assessing-relevance-1.html
  # for the examples in this test
  def test_kappa_wikipedia
    
    @gold_standard = Retreval::GoldStandard.new
    
    for i in (1..20) do 
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Alice", :relevant => true
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Bob", :relevant => true
    end
    
    for i in (21..25) do
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Alice", :relevant => true
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Bob", :relevant => false
    end
    
    for i in (26..35) do
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Alice", :relevant => false
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Bob", :relevant => true
    end
    
    for i in (36..50) do
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Alice", :relevant => false
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query#{i}", :user => "Bob", :relevant => false
    end
    puts "#{@gold_standard.kappa}"
    assert_equal(0.3939393939393937, @gold_standard.kappa, "Wikipedia kappa test failed!")
    
  end
  
end
