README
======

This is a simple API to evaluate information retrieval results. It allows you to load ranked and unranked query results and calculate various evaluation metrics (precision, recall, MAP, kappa) against a previously loaded gold standard.

Start this program from the command line with:

    retreval -l <gold-standard-file> -q <query-results> -f <format> -o <output-prefix>

The options are outlined when you pass no arguments and just call

    retreval

You will find further information in the RDOC documentation and the HOWTO section below.

If you want to see an example, use this command:

    retreval -l example/gold_standard.yml -q example/query_results.yml -f yaml -v


INSTALLATION
============

If you have RubyGems, just run

    gem install retreval

You can manually download the sources and build the Gem from there by `cd`ing to the folder where this README is saved and calling

    gem build retreval.gemspec

This will create a gem file called which you just have to install with `gem install <file>` and you're done.


HOWTO
=====

This API supports the following evaluation tasks:

- Loading a Gold Standard that takes a set of documents, queries and corresponding judgements of relevancy (i.e. "Is this document relevant for this query?")
- Calculation of the _kappa measure_ for the given gold standard

- Loading ranked or unranked query results for a certain query
- Calculation of _precision_ and _recall_ for each result
- Calculation of the _F-measure_ for weighing precision and recall
- Calculation of _mean average precision_ for multiple query results
- Calculation of the _11-point precision_ and _average precision_ for ranked query results

- Printing of summary tables and results

Typically, you will want to use this Gem either standalone or within another application's context.

Standalone Usage
================

Call parameters
---------------

After installing the Gem (see INSTALLATION), you can always call `retreval` from the commandline. The typical call is:

    retreval -l <gold-standard-file> -q <query-results> -f <format> -o <output-prefix>

Where you have to define the following options:

- `gold-standard-file` is a file in a specified format that includes all the judgements
- `query-results` is a file in a specified format that includes all the query results in a single file
- `format` is the format that the files will use (either "yaml" or "plain")
- `output-prefix` is the prefix of output files that will be created

Formats
-------

Right now, we focus on the formats you can use to load data into the API. Currently, we support YAML files that must adhere to a special syntax. So, in order to load a gold standard, we need a file in the following format:

 * "query"       denotes the query
 * "documents"   these are the documents judged for this query
 * "id"          the ID of the document (e.g. its filename, etc.)
 * "judgements"  an array of judgements, each one with:
 * "relevant"    a boolean value of the judgment (relevant or not)
 * "user"        an optional identifier of the user

Example file, with one query, two documents, and one judgement:

        - query: 12th air force germany 1957
          documents:
          - id: g5701s.ict21311
            judgements: []

          - id: g5701s.ict21313
            judgements: 
            - relevant: false
              user: 2

So, when calling the program, specify the format as `yaml`.
For the query results, a similar format is used. Note that it is necessary to specify whether the result sets are ranked or not, as this will heavily influence the calculations. You can specify the score for a document. By "score" we mean the score that your retrieval algorithm has given the document. But this is not necessary. The documents will always be ranked in the order of their appearance, regardless of their score. Thus in the following example, the document with "07" at the end is the first and "25" is the last, regardless of the score.

        ---
        query: 12th air force germany 1957
        ranked: true
        documents:
        -   score: 0.44034874
            document: g5701s.ict21307
        -   score: 0.44034874
            document: g5701s.ict21309
        -   score: 0.44034874
            document: g5701s.ict21311
        -   score: 0.44034874
            document: g5701s.ict21313
        -   score: 0.44034874
            document: g5701s.ict21315
        -   score: 0.44034874
            document: g5701s.ict21317
        -   score: 0.44034874
            document: g5701s.ict21319
        -   score: 0.44034874
            document: g5701s.ict21321
        -   score: 0.44034874
            document: g5701s.ict21323
        -   score: 0.44034874
            document: g5701s.ict21325
        ---
        query: 1612
        ranked: true
        documents:
        -   score: 1.0174774
            document: g3290.np000144
        -   score: 0.763108
            document: g3201b.ct000726
        -   score: 0.763108
            document: g3400.ct000886
        -   score: 0.6359234
            document: g3201s.ct000130
        ---

**Note**: You can also use the `plain` format, which will load the gold standard in a different way (but not the results):

        my_query        my_document_1     false
        my_query        my_document_2     true

See that every query/document/relevancy pair is separated by a tabulator? You can also add the user's ID in the fourth column if necessary.

Running the evaluation
-----------------------

After you have specified the input files and the format, you can run the program. If needed, the `-v` switch will turn on verbose messages, such as information on how many judgements, documents and users there are, but this shouldn't be necessary.

The program will first load the gold standard and then calculate the statistics for each result set. The output files are automatically created and contain a YAML representation of the results.

Calculations may take a while depending on the amount of judgements and documents. If there are a thousand judgements, always consider a few seconds for each result set.

Interpreting the output files
------------------------------

Two output files will be created:

- `output_avg_precision.yml`
- `output_statistics.yml`

The first lists the average precision for each query in the query result file. The second file lists all supported statistics for each query in the query results file.

For example, for a ranked evaluation, the first two entries of such a query result statistic look like this:

        --- 
        12th air force germany 1957: 
        - :precision: 0.0
          :recall: 0.0
          :false_negatives: 1
          :false_positives: 1
          :true_negatives: 2516
          :true_positives: 0
          :document: g5701s.ict21313
          :relevant: false
        - :precision: 0.0
          :recall: 0.0
          :false_negatives: 1
          :false_positives: 2
          :true_negatives: 2515
          :true_positives: 0
          :document: g5701s.ict21317
          :relevant: false

You can see the precision and recall for that specific point and also the number of documents for the contingency table (true/false positives/negatives). Also, the document identifier is given.

API Usage
=========

Using this API in another ruby application is probably the more common use case. All you have to do is include the Gem in your Ruby or Ruby on Rails application. For details about available methods, please refer to the API documentation generated by RDoc.

**Important**: For this implementation, we use the document ID, the query and the user ID as the primary keys for matching objects. This means that your documents and queries are identified by a string and thus the strings should be sanitized first.

Loading the Gold Standard
-------------------------

Once you have loaded the Gem, you will probably start by creating a new gold standard.

    gold_standard = GoldStandard.new

Then, you can load judgements into this standard, either from a file, or manually:

    gold_standard.load_from_yaml_file "my-file.yml"
    gold_standard.add_judgement :document => doc_id, :query => query_string, :relevant => boolean, :user => John

There is a nice shortcut for the `add_judgement` method. Both lines are essentially the same:

    gold_standard.add_judgement :document => doc_id, :query => query_string, :relevant => boolean, :user => John
    gold_standard << :document => doc_id, :query => query_string, :relevant => boolean, :user => John

Note the usage of typical Rails hashes for better readability (also, this Gem was developed to be used in a Rails webapp).

Now that you have loaded the gold standard, you can do things like:

        gold_standard.contains_judgement? :document => "a document", :query => "the query"
        gold_standard.relevant? :document => "a document", :query => "the query"


Loading the Query Results
-------------------------

Now we want to create a new `QueryResultSet`. A query result set can contain more than one result, which is what we normally want. It is important that you specify the gold standard it belongs to.

    query_result_set = QueryResultSet.new :gold_standard => gold_standard

Just like the Gold Standard, you can read a query result set from a file:

    query_result_set.load_from_yaml_file "my-results-file.yml"

Alternatively, you can load the query results one by one. To do this, you have to create the results (either ranked or unranked) and then add documents:

    my_result = RankedQueryResult.new :query => "the query"
    my_result.add_document :document => "test_document 1", :score => 13
    my_result.add_document :document => "test_document 2", :score => 11
    my_result.add_document :document => "test_document 3", :score => 3

This result would be ranked, obviously, and contain three documents. Documents can have a score, but this is optional. You can also create an Array of documents first and add them altogether:

        documents = Array.new
        documents << ResultDocument.new :id => "test_document 1", :score => 20
        documents << ResultDocument.new :id => "test_document 2", :score => 21
        my_result = RankedQueryResult.new :query => "the query", :documents => documents

The same applies to `UnrankedQueryResult`s, obviously. The order of ranked documents is the same as the order in which they were added to the result.

The `QueryResultSet` will now contain all the results. They are stored in an array called `query_results`, which you can access. So, to iterate over each result, you might want to use the following code:

        query_result_set.query_results.each_with_index do |result, index|
        # ...
        end

Or, more simply:

        for result in query_result_set.query_results
        # ...
        end

Calculating statistics
----------------------

Now to the interesting part: Calculating statistics. As mentioned before, there is a conceptual difference between ranked and unranked results. Unranked results are much easier to calculate and thus take less CPU time.

No matter if unranked or ranked, you can get the most important statistics by just calling the `statistics` method.

        statistics = my_result.statistics

In the simple case of an unranked result, you will receive a hash with the following information:

* `precision` - the precision of the results
* `recall` - the recall of the results
* `false_negatives` - number of not retrieved but relevant items
* `false_positives` - number of retrieved but nonrelevant
* `true_negatives` - number of not retrieved and nonrelevantv items
* `true_positives` - number of retrieved and relevant items

In case of a ranked result, you will receive an Array that consists of _n_ such Hashes, depending on the number of documents. Each Hash will give you the information at a certain rank, e.g. the following to lines return the recall at the fourth rank. 

        statistics = my_ranked_result.statistics
        statistics[3][:recall]

In addition to the information mentioned above, you can also get for each rank:

* `document` - the ID of the document that was returned at this rank
* `relevant` - whether the document was relevant or not

Calculating statistics with missing judgements
----------------------------------------------

Sometimes, you don't have judgements for all document/query pairs in the gold standard. If this happens, the results will be cleaned up first. This means that every document in the results that doesn't appear to have a judgement will be removed temporarily.

As an example, take the following results:

* A
* B
* C
* D

Our gold standard only contains judgements for A and C. The results will be cleaned up first, thus leading to:

* A
* C

With this approach, we can still provide meaningful results (for precision and recall).

Other statistics
----------------

There are several other statistics that can be calculated, for example the **F measure**. The F measure weighs precision and recall and has one parameter, either "alpha" or "beta". Get the F measure like so:

        my_result.f_measure :beta => 1

If you don't specify either alpha or beta, we will assume that beta = 1.

Another interesting measure is **Cohen's Kappa**, which tells us about the inter-agreement of assessors. Get the kappa statistic like this:

        gold_standard.kappa

This will calculate the average kappa for each pairwise combination of users in the gold standard.

For ranked results one might also want to calculate an **11-point precision**. Just call the following:

        my_ranked_result.eleven_point_precision

This will return a Hash that has indices at the 11 recall levels from 0 to 1 (with steps of 0.1) and the corresponding precision at that recall level.