require 'nokogiri'
require 'open-uri'
require 'uri'
require 'YAML'

$stdout.sync

##
# A bare-bones web crawler that tracks links between pages and records
# information about static assets (Javascript and CSS resources).
##

module Seaways
  CONFIG = {
    blacklist: %w(.zip .jpg .jpeg .gif .png .eps),
    debug: false,
  }

  def self.navigate(uri)
    Core.new(uri).run
  end

  class Core
    def initialize(host)
      @errors = []
      @pages = {}

      host = 'http://' << host unless host.start_with?('http://', 'https://')
      @target = make_uri(host)
      @queue = [@target]
    end

    def run
      while !@queue.empty?
        status
        uri = @queue.shift
        next if visited(uri)
        visit(uri)
      end
      status
      puts nil, @pages.to_yaml, @errors.to_yaml
    end

    def status
      printf("\rPages: %3d   Queue: %3d   Errors: %3d",
              @pages.size, @queue.size, @errors.size)
    end

    def visited(uri)
      @pages.key?(uri.to_s.to_sym)
    end

    def visit(uri)
      if doc = get(uri)
        links  = links(doc)
        assets = assets(doc)
        @pages[uri.to_s.to_sym] = make_page(links, assets)
        @queue += links[:local]
      else
        @pages[uri.to_s.to_sym] = nil
      end
    end

    def get(uri, tries=0)
      puts "get #{ uri }" if CONFIG[:debug]
      Nokogiri::HTML(open(uri.to_s))
    rescue RuntimeError, OpenURI::HTTPError => error
      if tries >= 5
        @errors << "Possible infinite loop: skipping #{ uri }"
      elsif error.message =~ /^redirection forbidden: (http.*) -> (http.*)$/
        puts "   `- #{$1} -> #{$2}" if CONFIG[:debug]
        uri = make_uri($2)
        return get(uri, (tries + 1)) if uri
      else
        @errors << "Error: #{ error } -- #{ uri }"
      end
      nil
    end

    def links(doc)
      [:local, :remote].zip(
        doc.css('a[href]').to_a
          .uniq { |a| a[:href].to_s }
          .map { |a| make_uri(a[:href]) }
          .compact
          .partition { |uri| follow_link?(uri) }
          .map do |list|
            list
              .collect { |uri| uri.to_s }
              .sort
          end
      ).to_h
    end

    def follow_link?(uri)
      uri.scheme.start_with?('http') &&
      uri.host.start_with?(@target.host, 'www' << @target.host) &&
      !uri.path.end_with?(*CONFIG[:blacklist]) &&
      !visited(uri)
    end

    def assets(doc)
      ref = lambda { |node| (node[:src] || node[:href]).to_s }

      [:js, :css].zip(
        doc.css('script[src], link[href]').to_a
          .uniq { |node| ref.call(node) }
          .partition { |node| node[:src] }
          .map do |list|
            list
              .collect { |node| ref.call(node) }
              .sort
          end
      ).to_h
    end

    def make_page(links, assets)
      {
        links: links,
        assets: assets,
      }
    end

    def make_uri(str)
      uri = URI::parse(str.to_s)
      uri.normalize!
      return uri if uri.scheme && !uri.scheme.start_with?('http')
      uri.scheme ||= @target.scheme
      uri.host ||= @target.host
      uri.path = '/' << uri.path unless uri.path.start_with?('/')
      uri.query = nil
      uri.fragment = nil
      uri.freeze
    rescue URI::InvalidURIError
      @errors << "Bad URI: #{ str }"
      nil
    end
  end
end
