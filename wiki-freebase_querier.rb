require 'csv'
require 'httparty'

class Querier
	OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE    # necessary to force freebase query
	
	@@row = []                         # the array in which each CSV row will get dumped

	@@loop_count = 0                   # counts how many rows have been examined
	@@missing_wiki_count = 0           # counts how many rows are missing wiki pages
	@@multiple_wiki_count = 0          # counts how many rows have multiple wiki pages
	@@missing_freebase_count = 0       # counts how many rows are missing freebase entries
	@@clean_count = 0                  # counts how many rows have no issues

	@@wiki_missing_iterator = 0        # iterators prevent headers from being written to CSV output files more than once
	@@wiki_multiple_iterator = 0
	@@freebase_missing_iterator = 0
	@@normal_iterator = 0

	# The script will add the below array as a header row to missing_wiki.csv, multiple_wiki.csv, missing_freebcase.csv, and clean.csv.
	@@header = ["Concept","Type","Relation","Link","Link Type","Concept ID","Concept Type ID","Relation ID","Link ID","Link Type ID","Wikipedia ID","Wikipedia URL","Wikipedia Title","Wikidata ID","Freebase ID","Freebcase MID"]

	# writes rows that return no wiki entries to missing.csv

	def self.log_missing_wiki      
		if @@wiki_missing_iterator == 0
			CSV.open('missing_wiki.csv', mode = "a+", options = { headers: @@header, write_headers: true }) { |missing_wiki|
				missing_wiki << @@row
			}
			@@wiki_missing_iterator += 1
		else
			CSV.open('missing_wiki.csv', mode = "a+", options = { headers: @@header }) { |missing_wiki|
				missing_wiki << @@row
			}
		end
		puts "No entry found! Logged to missing_wiki.csv."
		@@missing_wiki_count += 1
		@@loop_count += 1
		rest
	end

	# writes rows that return multiple wiki entries to multiple.csv

	def self.log_multiple_wiki
		# these conditionals are set up so that the header is written only once to each log file     
		if @@wiki_multiple_iterator == 0
			CSV.open('multiple_wiki.csv', mode = "a+", options = { headers: @@header, write_headers: true }) { |multiple_wiki|
				multiple_wiki << @@row
			}
			@@wiki_missing_iterator += 1
		else
			CSV.open('multiple_wiki.csv', mode = "a+", options = { headers: @@header }) { |multiple_wiki|
				multiple_wiki << @@row
			}
		end	
		puts "Multiple entries found! Logged to multiple_wiki.csv."
		@@multiple_wiki_count += 1
		@@loop_count += 1
		rest
	end

	# writes rows that return no freebase entries to missing_freebase.csv

	def self.log_missing_freebase   
		if @@freebase_missing_iterator == 0
			CSV.open('missing_freebase.csv', mode = "a+", options = { headers: @@header, write_headers: true }) {|missing_freebase|
				missing_freebase << @@row
			}
			@@freebase_missing_iterator += 1
		else
			CSV.open('missing_freebase.csv', mode = "a+", options = { headers: @@header }) {|missing_freebase|
				missing_freebase << @@row
			}
		end	
		puts "Missing freebase entry! Logged to missing_freebase.csv"
		@@missing_freebase_count +=1
		@@loop_count += 1
		rest
	end

	# writes rows that return all data to clean.csv

	def self.log_clean_rows          
		if @@normal_iterator == 0
			CSV.open('clean.csv', mode = "a+", options = { headers: @@header, write_headers: true }) { |file|
				file << @@row
			}
			@@normal_iterator += 1
		else
			CSV.open('clean.csv', mode = "a+", options = { headers: @@header }) { |file|
				file << @@row
			}
		end
		puts "Logged to clean.csv."
		@@clean_count += 1
		@@loop_count += 1
		rest	
	end

	# inserts sleep interval after API calls

	def self.rest                    
		puts "Sleeping..."
		sleep 1
		puts "-----------"
	end

	# prints result of querying to console

	def self.print_result
		puts "Done! Completed #{@@loop_count} rows. #{@@clean_count} were clean. #{@@missing_wiki_count} logged to missing.csv. #{@@multiple_wiki_count} logged to multiple.csv. #{@@missing_freebase_count} logged to missing_freebase.csv."
	end
end

CSV.foreach('test.csv', options = { headers: true }) do |csv|      # replace 'test.csv' with input file
	@@row = csv
	nyt_wiki_title = @@row[3]
	
	#WIKIPEDIA API CALL
	base_wiki_url = 'http://en.wikipedia.org/w/api.php?action=query&prop=info&inprop=url&titles=wiki-title&redirects&format=json'
	wiki_call = HTTParty.get(URI.encode(base_wiki_url.gsub(/wiki-title/, nyt_wiki_title.to_s)))
	puts "Made Wikipedia query for #{@@row[3]}..."
	wiki_call_pages = wiki_call["query"]["pages"]

	if wiki_call_pages.keys == ["-1"]   # execute if row does not return a wiki entry
		Querier.log_missing_wiki
		next
	end
	

	if wiki_call_pages.keys[1] != nil   # execute if row returns multiple wiki entries
		Querier.log_multiple_wiki
		next
	end

	wiki_id = @@row[10] = wiki_call_pages.values.first.values[0] 
	wiki_url = @@row[11] = wiki_call_pages.values.first.values[9]
	wiki_title = @@row[12] = wiki_call_pages.values.first.values[2]

	# FREEBASE API CALL
	base_freebase_url = 'https://www.googleapis.com/freebase/v1/mqlread?query={"mid":null,"id":null,"key":{"namespace":"/wikipedia/en_id","value":"wiki-id","limit":1}}&key=AIzaSyD8p3wHSxpqOhDHsL87ekN2a2YYP5NxB34'
	freebase_call = HTTParty.get(URI.encode(base_freebase_url.gsub(/wiki-id/, wiki_id.to_s)))
	puts "Made Freebase query for Wiki ID##{@@row[10]}..."

	if freebase_call["result"] == nil   # execute if row does not return a freebase entry
		Querier.log_missing_freebase
		next
	end

	freebase_id = @@row[14] = freebase_call["result"]["id"]
	freebase_mid = @@row[15] = freebase_call["result"]["mid"]

	# IF ALL DATA FOUND, WRITE OUT TO CLEAN.CSV

	Querier.log_clean_rows	
end

Querier.print_result




