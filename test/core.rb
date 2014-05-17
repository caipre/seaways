#!/usr/bin/env rspec
require_relative '../lib/seaways'
include Seaways

describe Seaways do
   before do
      @seaways = Seaways::Core.new('http://example.org')
   end

   describe '#visit' do
      context 'with a valid href' do
         it 'inserts a page' do
            @seaways.visit('http://example.org')
            expect(@seaways.pages).to have_key(:'http://example.org')
         end

         # Needs document mock; example.org has no local links
         it 'adds local links to the queue'
      end

      context 'with an invalid href' do
         it 'inserts a nil page' do
            @seaways.visit('http://example!org')
            expect(@seaways.pages).to  eql({:'http://example!org' => nil})
         end
      end
   end

   describe '#get' do
      context 'with a valid href' do
         it 'returns a document'
         it 'follows redirects'
         it "doesn't infinitely redirect"
      end

      context 'with an invalid href' do
         it 'returns nil'
      end
   end

   describe '#links' do
      it 'separates local and remote URIs'
   end

   describe '#assets' do
      it 'separates local and remote assets'
   end

   describe '#follow_link?' do
      context 'with a blacklisted href' do
         it 'returns false' do
            uri = @seaways.make_uri('http://example.org/image.jpg')
            expect(@seaways.follow_link?(uri)).to be_false
         end
      end

      context 'with an href in the local domain' do
         it 'returns true' do
            uri = @seaways.make_uri('http://example.org/foo/bar')
            expect(@seaways.follow_link?(uri)).to be_true
         end

         it 'returns true (www subdomain)' do
            uri = @seaways.make_uri('http://www.example.org/foo/bar')
            expect(@seaways.follow_link?(uri)).to be_true
         end

         it 'returns true (different scheme)' do
            uri = @seaways.make_uri('https://example.org/foo/bar')
            expect(@seaways.follow_link?(uri)).to be_true
         end
      end

      context 'with an href to a remote domain' do
         it 'returns false' do
            uri = @seaways.make_uri('http://google.com')
            expect(@seaways.follow_link?(uri)).to be_false
         end

         it 'returns false (non-www subdomain)' do
            uri = @seaways.make_uri('http://static.example.org')
            expect(@seaways.follow_link?(uri)).to be_false
         end
      end
   end

   describe '#make_uri' do
      context 'with a valid href' do
         it 'parses the scheme, host, and path'
         it 'drops the querystring'
         it 'drops the fragment'
      end

      context 'with a partial href' do
         it 'uses a default scheme'
         it 'uses a default host'
         it 'adds a path separator'
      end

      context 'with a valid, non-http href' do
         it 'retruns the uri'
      end

      context 'with an invalid href' do
         it 'records an error'
         it 'returns nil'
      end
   end
end
