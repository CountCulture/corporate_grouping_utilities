# encoding: UTF-8
# Usage ruby ./wikipedia_to_corporate_groupings_csv.rb
require 'nokogiri'
require 'open-uri'
require 'csv'
require 'byebug'

def env_var_or_request_from_user(var_name)
  var_name = var_name.to_s
  return ENV[var_name.upcase] if ENV[var_name.upcase]
  message = "Enter #{var_name.gsub(/_/,' ')}"
  puts message
  res = $stdin.gets.chomp.strip
  res.empty? ? nil : res
end

wikipedia_id = env_var_or_request_from_user(:wikipedia_id)

doc = Nokogiri.HTML(open("https://en.wikipedia.org/wiki/#{wikipedia_id}"))

table_css_selector = env_var_or_request_from_user(:data_table_css_selector)
wikipedia_links = doc.search("#{table_css_selector} tr")[1..-1].collect{|tr| tr.at('a')}.compact
# debugger
# snippet for collecting company names from set of wikipedia links, e.g. from https://en.wikipedia.org/wiki/FTSE_100_Index
data_from_wikipedia_links = wikipedia_links.collect do |l|
  short_name = l.inner_text
  puts "Getting details for #{short_name}"# if ENV['VERBOSE']
  entry_wikipedia_id = l[:href].split('/').last
  default_entry = {:name => short_name, :short_name =>short_name, :wikipedia_id=> entry_wikipedia_id}

  if l[:class] == 'new'
    puts "**No wikipedia page for #{short_name}"
    next default_entry
  end
  doc = Nokogiri.HTML(open("https://en.wikipedia.org" + l[:href]))
  if info_box = doc.at('table.infobox')
    name = doc.at('table.infobox.vcard caption.fn.org').inner_text
    hq = doc.at_xpath('//table[contains(@class,"infobox")]//tr[th[contains(text(), "Headquarters")]]/td').inner_text rescue nil
    jurisdiction = hq.split(',').last if hq and hq.split(',').size < 3
    {:name => name, :short_name =>short_name, :wikipedia_id=> entry_wikipedia_id, :headquarters => hq, :jurisdiction => jurisdiction}
    # {:name => name, :short_name=> l.inner_text, :wikipedia_id => l[:href].split('/').last }
  else
    puts "**No infobox found for #{short_name}"
    default_entry
  end
end

csv_file_location = "#{wikipedia_id}.csv"
csv = CSV.open(csv_file_location,'w', :headers=>[:name, :jurisdiction, :short_name,:wikipedia_id,:headquarters], :write_headers=>true) do |csv|
  data_from_wikipedia_links.each{|hsh| csv << hsh }
end

puts "CSV file written to #{csv_file_location}"
