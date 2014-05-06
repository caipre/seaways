#!/usr/bin/env ruby -w
require 'nokogiri'
require 'open-uri'
require 'uri/http'

$stdout.sync

def same_domain?(uri)
  return uri[%r(^/[^/]+)] ||
         URI.parse(uri).hostname.start_with?(ARGV.first)
rescue NoMethodError
end

def fetch(uri)
  uri = "#{ ARGV.first }#{ uri }" if uri.start_with?('/')
  print "fetching #{ uri }"

  begin
    links = Nokogiri::HTML(open(uri)).css('a[href]')
  rescue RuntimeError
    puts ' <-- BROKEN'
    return
  end
  puts " => #{ links.size } links"

  links.each do |link|
    next unless same_domain?(link[:href])
    next if link[:href][/\..+$/]

    unless @index.key?(link[:href])
      @index[link[:href]] ||= 1
      fetch(link[:href])
    end
  end
end

@index = {}
fetch(ARGV.first)
puts
puts @index
