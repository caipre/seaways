#!/usr/bin/env ruby -w
require 'nokogiri'
require 'open-uri'
require 'uri/http'

$stdout.sync

def init(hostname)
  @hostname = hostname
  @blacklist = %w(jpg gif png zip)

  puts filter(parse(fetch(@hostname)))
end

def fetch(uri)
  puts "fetch #{ uri }"
  Nokogiri::HTML(open(uri))
rescue RuntimeError => error
  puts error
end

def parse(doc)
  {
    links:   doc.css('a[href]'),
    scripts: doc.css('script[src]'),
    styles:  doc.css('link[href]'),
  }
end

def filter(assets)
  assets.each do |type, list|
    list.select! do |asset|
      same_domain?(asset) && !asset.end_with?(*@blacklist)
    end
  end
end

def same_domain?(uri)
  return (uri.start_with?('/') && !uri.start_with?('//')) ||
         URI.parse(uri).hostname.start_with?(@hostname)
rescue NoMethodError
end

init(ARGV.first)
