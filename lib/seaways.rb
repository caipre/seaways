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

  def self.navigate(href)
    Core.new(href).run
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
        href = @queue.shift
        visit(href) unless visited(href)
      end
      status
      puts nil, @pages.to_yaml, @errors.to_yaml
    end

    def status
      printf("\rPages: %3d   Queue: %3d   Errors: %3d",
              @pages.size, @queue.size, @errors.size)
    end

    def visit(href)
      if doc = get(href)
        @pages[href.to_sym] = {
          links: links(doc),
          assets: assets(doc),
        }
        @queue += links[:local].select { |href| !visited(href) }
      else
        @pages[href.to_sym] = nil
      end
    end

    def visited(href)
      @pages.key?(href.to_sym)
    end

    def get(href, tries=0)
      puts "get #{ href }" if CONFIG[:debug]
      Nokogiri::HTML(open(href))
    rescue RuntimeError, OpenURI::HTTPError => error
      if tries >= 5
        @errors << "Possible infinite loop: skipping #{ href }"
      elsif error.message =~ /^redirection forbidden: (http.*) -> (http.*)$/
        puts "   `- #{$1} -> #{$2}" if CONFIG[:debug]
        uri = make_uri($2)
        return get(uri.to_s, (tries + 1)) if uri
      else
        @errors << "Error: #{ error } -- #{ href }"
      end
      nil
    end

    def links(doc)
      [:local, :remote].zip(
        doc.css('a[href]').to_a
          .map { |a| make_uri(a[:href]) }
          .compact
          .partition { |uri| follow_link?(uri) }
          .map do |list|
            list
              .uniq { |uri| uri.to_s }
              .collect { |uri| uri.to_s }
              .sort
          end
      ).to_h
    end

    def follow_link?(uri)
      uri.scheme.start_with?('http') &&
      uri.host.start_with?(@target.host, 'www' << @target.host) &&
      !uri.path.end_with?(*CONFIG[:blacklist])
    end

    def assets(doc)
      ref = lambda { |node| (node[:src] || node[:href]).to_s }

      [:js, :css].zip(
        doc.css('script[src], link[href]').to_a
          .partition { |node| node[:src] }
          .map do |list|
            list
              .uniq { |node| ref.call(node) }
              .collect { |node| ref.call(node) }
              .sort
          end
      ).to_h
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
