# Author:  Nick Platt <platt.nicholas@gmail.com>
# License: MIT <http://opensource.org/licenses/MIT>

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
    # Won't follow links to these extensions
    blacklist: %w(.zip .jpg .jpeg .gif .png .eps),

    # Allow N redirections when requesting a uri
    max_redirects: 5,

    # Enable some additional logging
    debug: false,
  }

  def self.navigate(href)
    Core.new(href).run
  end

  class Core
    attr_accessor :pages, :queue, :errors

    def initialize(host)
      @pages = {}  # mapping from href to page hash
      @errors = []

      host = 'http://' << host unless host.start_with?('http://', 'https://')
      @target = make_uri(host)
      @queue = [@target.to_s]
    end

    ##
    # Main loop.
    ##
    def run
      while !@queue.empty?
        status
        @href = @queue.shift
        visit(@href) unless visited(@href)
      end
      status
      puts @pages.to_yaml
    end

    ##
    # Print a simple status line to show progress. Write to stderr to allow
    # standard unix shell pipelining..
    ##
    def status
      $stderr.printf("\rPages: %3d  Queue: %3d  Errors: %3d",
                     @pages.size, @queue.size, @errors.size)
    end

    ##
    # Build and record page hash with links and assets. Enqueue any new hrefs.
    # Record failed requests as nil to prevent hitting them again.
    #
    # @param href string
    ##
    def visit(href)
      if doc = get(href)
        links = links(doc)
        assets = assets(doc)
        @pages[href.to_sym] = {
          links: links,
          assets: assets,
        }
        @queue += links[:local].select { |h| !visited(h) }
      else
        @pages[href.to_sym] = nil
      end
    end

    def visited(href)
      @pages.key?(href.to_sym)
    end

    ##
    # Perform HTTP request and parse the response. Handle errors gracefully.
    #
    # @param href  string
    # @param tries int
    #
    # @return doc, nil
    ##
    def get(href, tries=0)
      puts "get #{ href }" if CONFIG[:debug]
      Nokogiri::HTML(open(href))
    rescue RuntimeError, OpenURI::HTTPError => error
      if tries >= CONFIG[:max_redirects]
        @errors << "Possible infinite loop: skipping #{ href }"
      elsif error.message =~ /^redirection forbidden: (http.*) -> (http.*)$/
        # This is ugly but open-uri doesn't natively handle redirects.
        puts "  `- #{$1} -> #{$2}" if CONFIG[:debug]
        uri = make_uri($2)
        if uri
          @href = uri.to_s
          return get(@href, (tries + 1))
        end
      else
        @errors << "Error: #{ error } -- #{ @href }"
      end
      nil
    rescue URI::InvalidURIError, Errno::ENOENT, Errno::ECONNRESET => error
      @errors << "Error: #{ error } -- #{ @href }"
      nil
    end

    ##
    # Parse hrefs from document and separate by domain.
    #
    # @param doc Nokogiri document
    #
    # @return hash
    ##
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
      uri.host.start_with?(@target.host, 'www.' << @target.host) &&
      !uri.path.end_with?(*CONFIG[:blacklist])
    end

    ##
    # Parse Javascript and CSS assets from document and separate.
    #
    # @param doc Nokogiri document
    #
    # @return hash
    #$
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

    ##
    # Normalize URI; insert data as necessary.
    #
    # @param href string
    #
    # @return uri, nil
    ##
    def make_uri(href)
      uri = URI::parse(href.to_s)
      uri.normalize!
      return uri if uri.scheme && !uri.scheme.start_with?('http')
      uri.scheme ||= @target.scheme
      uri.host ||= @target.host
      uri.path = '/' << uri.path unless uri.path.start_with?('/')
      uri.query = nil
      uri.fragment = nil
      uri
    rescue URI::InvalidURIError
      @errors << "Bad URI: #{ href } on page #{ @href }"
      nil
    end
  end
end
