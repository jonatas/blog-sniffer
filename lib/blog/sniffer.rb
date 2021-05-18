require "mechanize"
require "pry"
require 'benchmark'
require_relative "agent"
require_relative "page"
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

      def enqueue(url)
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

    class EngineeringDocs
      attr_reader :root

      def initialize(root: "https://docs.timescale.com")
        @root = root
      end

      def fetch(url)
        data, time_to_fetch = spider.fetch(url)
        return [data, {time_to_fetch: time_to_fetch, url: build_url(url)}]
      end

      def process(url)
        page, extra_payload = fetch(url)
        metadata = metadata_from(page).merge(extra_payload)

        page.links_with(href: /^\/|^#{Regexp.escape(@root)}/).each do |link|
          next if link.href =~ /\.(mp4|pdf|png|docx|jpg|jpeg)$/
          spider.enqueue(build_url(link.href))
        end
        metadata
      end

      def build_url url
        case url.to_s
        when '/' then @root
        when /^https?:\/\// then normalize_url(url.to_s)
        else normalize_url(@root + url)
        end
      end

      def normalize_url url
        uri = URI.parse(url.to_s)
        uri.normalize!
        uri.query = nil
        URI.encode(uri.to_s.gsub(/[\?#]+$/,''))
      rescue
        url.split("?").first
      end

      def metadata_from(page)
        {
          title: normalize(page.title).first,
          headers: normalize(*page.search("h1, h2, h3, h4").map(&:text)),
          links: page.links.each_with_object({}) {|link, resume|
            resume[normalize(link.text).first] = normalize_url(link.href)},
          codeblocks: normalize(*page.search("pre").map(&:text)),
          body: normalize(*page.search("p, li").map(&:text).uniq),
          html_size: page.body.size,
        }
      end

      def normalize *strings
        strings.compact.map{|s|s.strip.gsub(/\t|\n/,' ').gsub(/\s\s*/,' ')}
      end

      def results(&block)
        spider.results(&block)
      end

      private

      def spider
        @spider ||= Spider.new(self)
      end
    end

    class Error < StandardError; end
  end
end
