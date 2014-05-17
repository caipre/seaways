#!/usr/bin/env rspec
require_relative '../lib/seaways'
include Seaways

describe Seaways do
   before do
      @seaways = Core.new('http://example.org')
   end

   describe '#visit' do
      context 'with a valid href' do
         it 'inserts a page'
         it 'adds local links to the queue'
      end

      context 'with an invalid href' do
         it 'inserts a nil page'
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
         it 'returns false'
      end

      context 'with an href in the local domain' do
         it 'returns true'
         it 'returns true (www subdomain)'
         it 'returns true (different scheme)'
      end

      context 'with an href to a remote domain' do
         it 'returns false'
         it 'returns false (non-www subdomain)'
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
