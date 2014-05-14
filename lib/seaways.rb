require 'nokogiri'
require 'open-uri'
require 'uri'
require 'YAML'

$stdout.sync

module Seaways
  def self.navigate(uri)
    Core.new(uri).run
  end

  class Core
    def initialize(host)
      host = 'http://' << host unless host.start_with?('http://', 'https://')
      @target = make_uri(host)
      @queue = [@target]
      @pages = {}
      @blacklist = %w(.zip .jpg .jpeg .gif .png .eps)
    end

    def run
      while !@queue.empty?
        uri = @queue.shift
        next if @pages.key?(uri.to_s.to_sym)
        @pages[uri.to_s.to_sym] = nil
        doc = get(uri) || next
        links  = links_to_follow(doc)
        assets = static_assets(doc)
        @pages[uri.to_s.to_sym] = make_page(links, assets)
        @queue += links
      end

      puts @pages.to_yaml
    end

    def links_to_follow(doc)
      doc.css('a[href]').to_a
        .map { |link| make_uri(link[:href]) }
        .uniq
        .select do |uri|
          uri &&
          uri.scheme.start_with?('http') &&
          uri.host.start_with?(@target.host, 'www' << @target.host) &&
          !uri.path.end_with?(*@blacklist)
        end
    end

    def make_uri(str)
      raise TypeError unless str.respond_to?(:to_s)
      uri = URI::parse(str.to_s)
      uri.normalize!
      return uri if uri.scheme && !uri.scheme.start_with?('http')
      uri.scheme ||= @target.scheme
      uri.host ||= @target.host
      uri.path = '/' << uri.path unless uri.path.start_with?('/')
      uri.query = nil
      uri.fragment = nil
      uri.freeze
    rescue URI::InvalidURIError => error
      puts "  > bad link: #{ str }"
    end

    def make_page(links, assets)
      {
        links:  links.collect { |uri| uri.to_s },
        assets: assets,
      }
    end

    def static_assets(doc)
      {
        js:  doc.css('script[src]').collect { |script| script[:src] },
        css: doc.css('link[href]').collect { |style| style[:href] },
      }
    end

    def get(uri, tries=5)
      puts "get #{ uri }"
      Nokogiri::HTML(open(uri.to_s))
    rescue RuntimeError, OpenURI::HTTPError => error
      if tries == 0
        puts "won't try again"
      elsif error.message =~ /^redirection forbidden: (http.*) -> (http.*)$/
        puts "   `- #{$1} -> #{$2}"
        uri = make_uri($2)
        get(uri, tries - 1)
      else
        puts "   `- #{ error }"
      end
    end
  end
end
