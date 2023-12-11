require "mechanize"
require "pry"
require 'benchmark'
require_relative "agent"
require_relative "page"
require_relative "page_docs"
require_relative "target_sites"

module Blog
  module Sniffer
    class Spider
      REQUEST_INTERVAL = 1
      MAX_URLS = 1000

      def initialize(processor, options = {})
        @processor = processor

        @urls     = []
        @interval = options.fetch(:interval, REQUEST_INTERVAL)
        @max_urls = options.fetch(:max_urls, MAX_URLS)

        enqueue(@processor.root)
      end

      def ignore?(url)
        false
      end

      def enqueue(url)
        return if ignore?(url)
        return if @urls.include? url

        @urls << url
      end


      def results
        return enum_for(:results) unless block_given?

        enqueued_urls.each do |url|
          begin
            log "Handling", url.inspect

            yield @processor.process(url) if block_given?
          end
        rescue => ex
          log "Error fetching #{url}", ex
        end
      end

      def fetch(url)
        data = nil
        performance= Benchmark.measure{
          data = Blog::Agent.get(url)
        }
        return data, performance.real
      end

      private

      def enqueued_urls
        Enumerator.new do |y|
          index = 0
          while index < @urls.count && index <= @max_urls
            url = @urls[index]
            index += 1
            next unless url
            y.yield url
          end
        end
      end

      def log(label, info)
        puts "%-10s: %s" % [label, info]
      end

    end


    class Error < StandardError; end
  end
end
