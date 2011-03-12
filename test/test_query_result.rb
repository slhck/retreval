require 'test/unit'
require 'retrievalAPI/gold_standard'
require 'retrievalAPI/query_result'

# Some basic unit tests for QueryResult
# Unranked results include 4 documents of 10, which are all retrieved.
# The ranked results are evaluated from this table:
#      Index Relevant  Precision   Recall        Document ID
#      1     [X]       1.000        0.250        doc1
#      2     [X]       1.000        0.500        doc2
#      3     [ ]       0.667        0.500        doc5
#      4     [X]       0.750        0.750        doc3
#      5     [ ]       0.600        0.750        doc6
#      6     [X]       0.667        1.000        doc4
#      7     [ ]       0.571        1.000        doc7
#      8     [ ]       0.500        1.000        doc8
#      9     [ ]       0.444        1.000        doc9
#      10    [ ]       0.400        1.000        doc10
class TestQueryResult < Test::Unit::TestCase 
  
  
  # Adds 10 test judgements to this test case
  def add_test_judgements
    
    @gold_standard = Retreval::GoldStandard.new
    
    for i in (1..4) do
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query1", :relevant => true
    end
    
    for i in (5..10) do
      @gold_standard.add_judgement :document => "doc#{i}", :query => "query1", :relevant => false
    end
    
  end
  
  
  # Adds the unranked query results to be tested against to this test case
  def add_unranked_query_result
    
    @query_result = Retreval::UnrankedQueryResult.new :query => "query1", :gold_standard => @gold_standard
    
    for i in (1..4) do
      @query_result.add_document :id => "doc#{i}"
    end
    
    for i in (5..10) do
      @query_result.add_document :id => "doc#{i}"
    end
    
  end
  
  
  # Adds the ranked query results to be tested against to this test case
  def add_ranked_query_result
    
    @query_result = Retreval::RankedQueryResult.new :query => "query1", :gold_standard => @gold_standard
    
    @query_result.add_document :id => "doc1"
    @query_result.add_document :id => "doc2"
    @query_result.add_document :id => "doc5"
    @query_result.add_document :id => "doc3"
    @query_result.add_document :id => "doc6"
    @query_result.add_document :id => "doc4"
    @query_result.add_document :id => "doc7"
    @query_result.add_document :id => "doc8"
    @query_result.add_document :id => "doc9"
    @query_result.add_document :id => "doc10"
    
  end
  
  
  # Tests the unranked precision
  def test_unranked_precision
    
    add_test_judgements
    add_unranked_query_result
    assert_equal(0.4, @query_result.statistics[:precision])
    
  end
  
  
  # Tests if the unranked recall is calculated correctly
  def test_unranked_recall

    add_test_judgements    
    add_unranked_query_result
    assert_equal(1.0, @query_result.statistics[:recall])
    
  end
  
  
  # Tests if the ranked recalls are calculated correctly
  def test_ranked_precision
    
    add_test_judgements
    add_ranked_query_result
    expected_precision = [
        1,
        1,
        0.6666666666666666,
        0.75,
        0.6,
        0.6666666666666666,
        0.5714285714285714,
        0.5,
        0.4444444444444444,
        0.4
      ]
    @query_result.statistics.each_with_index do |rank, index|
      assert_equal(expected_precision[index], rank[:precision])
    end
    
  end
  
  # Tests if the ranked recalls are calculated correctly
  def test_ranked_recall
    
    add_test_judgements
    add_ranked_query_result
    expected_recall = [
        0.25,
        0.5,
        0.5,
        0.75,
        0.75,
        1,
        1,
        1,
        1,
        1
      ]
    @query_result.statistics.each_with_index do |rank, index|
      assert_equal(expected_recall[index], rank[:recall])
    end
    
  end
  
  
  # Tests the correct calculation of the eleven point precision as outlined here:
  # http://nlp.stanford.edu/IR-book/html/htmledition/evaluation-of-ranked-retrieval-results-1.html
  def test_eleven_point_precision
    
    add_test_judgements
    add_ranked_query_result
    expected_results = [
        1.0,
        1.0,
        1.0,
        0.6666666666666666,
        0.6666666666666666,
        0.6666666666666666,
        0.6,
        0.6,
        0.4,
        0.4,
        0.4,
      ]
    @query_result.eleven_point_precision.each_with_index do |p, index|
      assert_equal(expected_results[index], p[1])
    end
    
  end
  
  
end
