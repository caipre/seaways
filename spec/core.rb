#!/usr/bin/env rspec
require_relative '../lib/seaways'
require 'nokogiri'

include Nokogiri
include Seaways

describe Seaways do
  let (:html) do
    <<-html
      <html>
        <head>
          <title>A stubbed page</title>
          <link href="/style.css" />
          <link href="http://remotehost.org/style.css" />
          <script src="/script.js"></script>
          <script src="http://remotehost.org/script.js" />
        </head>
        <body>
          <a name="anchor">Named anchor</a>
          <a href="/foo/bar">Link to visit</a>
          <a href="http://localhost.org">Already visited link</a>
          <a href="http://remotehost.com">Remote link</a>
        </body>
      </html>
    html
  end

  let (:document) { Nokogiri::HTML(html) }


  describe '#visit' do
    before(:each) do
      @seaways = Seaways::Core.new('http://localhost.org')
      @seaways.stub(:get).and_return(document)
      href = @seaways.queue.shift
      @seaways.visit(href)
    end

    context 'with a valid href' do
      it 'inserts a page' do
        expect(@seaways.pages).to have_key(:'http://localhost.org/')
      end

      it 'adds local links to the queue' do
        expect(@seaways.queue).to include('http://localhost.org/foo/bar')
        expect(@seaways.queue).to have(1).item
      end
    end
  end

  describe '#visit' do
    before(:each) do
      @seaways = Seaways::Core.new('http://localhost!org')
      @seaways.visit('http://localhost!org/')
    end

    context 'with an invalid href' do
      it 'inserts a nil page' do
        expect(@seaways.pages).to eql({:'http://localhost!org/' => nil})
      end
    end
  end

  describe '#get' do
    before(:each) do
      @seaways = Seaways::Core.new('http://localhost.org')
    end

    context 'with a valid href' do
      it 'returns a document' do
        @seaways.stub(:open).and_return(html)
        expect(@seaways.get('http://localhost.org')).to be_an_instance_of(Nokogiri::HTML::Document)
      end

      it 'follows redirects' do
        @redirect = true
        @seaways.stub(:open).and_return do
          if @redirect
            @redirect = false
            raise RuntimeError, 'redirection forbidden: http://localhost.org -> https://localhost.org'
          else
            html
          end
        end
        expect(@seaways.get('http://localhost.org')).to be_an_instance_of(Nokogiri::HTML::Document)
      end

      it "doesn't infinitely redirect" do
        @redirect = true
        @seaways.stub(:open).and_raise(RuntimeError, 'redirection forbidden: http://localhost.org -> https://localhost.org')
        expect(@seaways.get('http://localhost.org')).to be_nil
      end
    end

    context 'with an invalid href' do
      it 'records the error' do
        @seaways.get('http://localhost!org')
        expect(@seaways.errors).to have(1).item
      end

      it 'returns nil' do
        expect(@seaways.get('http://localhost!org')).to be_nil
      end
    end
  end

  describe '#links' do
    before(:each) do
      @seaways = Seaways::Core.new('http://localhost.org')
      @seaways.stub(:get).and_return(document)
      href = @seaways.queue.shift
      @seaways.visit(href)
    end

    it 'separates local and remote URIs' do
      links = [
        { href: 'http://localhost.org' },
        { href: 'http://remotehost.com' },
      ]
      doc = double
      doc.stub(css: links)

      expect(@seaways.links(doc)).to eq(
        local: ['http://localhost.org/'],
        remote: ['http://remotehost.com/']
      )
    end
  end

  describe '#assets' do
    before(:each) do
      @seaways = Seaways::Core.new('http://localhost.org')
      @seaways.stub(:get).and_return(document)
      href = @seaways.queue.shift
      @seaways.visit(href)
    end

    it 'separates local and remote assets' do
      assets = [
        { src: '//cdnjs.cloudflare.com/ajax/libs/ace/1.1.3/ace.js' },
        { href: '/css/normalize.css' },
      ]
      doc = double
      doc.stub(css: assets)

      expect(@seaways.assets(doc)).to eq(
        js: ['//cdnjs.cloudflare.com/ajax/libs/ace/1.1.3/ace.js'],
        css: ['/css/normalize.css']
      )
    end
  end

  describe '#follow_link?' do
    before(:each) do
      @seaways = Seaways::Core.new('http://localhost.org')
      @seaways.stub(:get).and_return(document)
      href = @seaways.queue.shift
      @seaways.visit(href)
    end

    context 'with a blacklisted href' do
      it 'returns false' do
        uri = @seaways.make_uri('http://localhost.org/image.jpg')
        expect(@seaways.follow_link?(uri)).to be_false
      end
    end

    context 'with an href in the local domain' do
      it 'returns true' do
        uri = @seaways.make_uri('http://localhost.org/foo/bar')
        expect(@seaways.follow_link?(uri)).to be_true
      end

      it 'returns true (www subdomain)' do
        uri = @seaways.make_uri('http://www.localhost.org/foo/bar')
        expect(@seaways.follow_link?(uri)).to be_true
      end

      it 'returns true (different scheme)' do
        uri = @seaways.make_uri('https://localhost.org/foo/bar')
        expect(@seaways.follow_link?(uri)).to be_true
      end
    end

    context 'with an href to a remote domain' do
      it 'returns false' do
        uri = @seaways.make_uri('http://remotehost.com')
        expect(@seaways.follow_link?(uri)).to be_false
      end

      it 'returns false (non-www subdomain)' do
        uri = @seaways.make_uri('http://static.localhost.org')
        expect(@seaways.follow_link?(uri)).to be_false
      end
    end
  end

  describe '#make_uri' do
    before(:each) do
      @seaways = Seaways::Core.new('http://localhost.org')
      @seaways.stub(:get).and_return(document)
      href = @seaways.queue.shift
      @seaways.visit(href)
    end

    context 'with a valid href' do
      it 'parses the scheme, host, and path' do
        uri = @seaways.make_uri('http://localhost.org')
        expect(uri).to respond_to(:scheme, :host, :path)
        expect(uri.scheme).to eql('http')
        expect(uri.host).to eql('localhost.org')
        expect(uri.path).to eql('/')
      end

      it 'drops the querystring' do
        uri = @seaways.make_uri('http://localhost.org/foo?bar=baz')
        expect(uri).to respond_to(:query)
        expect(uri.query).to be_nil
      end

      it 'drops the fragment' do
        uri = @seaways.make_uri('http://localhost.org/foo?bar=baz')
        expect(uri).to respond_to(:fragment)
        expect(uri.fragment).to be_nil
      end
    end

    context 'with a partial href' do
      it 'uses a default scheme' do
        uri = @seaways.make_uri('/foo/bar')
        expect(uri.scheme).to eql('http')
      end

      it 'uses a default host' do
        uri = @seaways.make_uri('/foo/bar')
        expect(uri.host).to eql('localhost.org')
      end

      it 'adds a path separator' do
        uri = @seaways.make_uri('http://localhost.org')
        expect(uri.path).to eql('/')
      end
    end

    context 'with a valid, non-http href' do
      it 'returns the uri' do
        uri = @seaways.make_uri('mailto:admin@localhost.org')
        expect(uri.scheme).to eql('mailto')
      end
    end

    context 'with an invalid href' do
      it 'records an error' do
        uri = @seaways.make_uri('http://localhost!org')
        expect(@seaways.errors).to have(1).item
      end

      it 'returns nil' do
        uri = @seaways.make_uri('http://localhost!org')
        expect(uri).to be_nil
      end
    end
  end
end
