require "erb"
module Blog
  module Sniffer
    class PageDocs
      attr_reader :root
      include ERB::Util

      def initialize(root: "https://docs.timescale.com")
        @root = root
        @path = URI.parse(root).path
        @inner_pages = /^#{Regexp.escape(@path)}|^#{Regexp.escape(@root)}/
      end

      def fetch(url)
        data, time_to_fetch = spider.fetch(url)
        return [data, {time_to_fetch: time_to_fetch, url: build_url(url)}]
      end

      def process(url)
        page, extra_payload = fetch(url)
        metadata = metadata_from(page).merge(extra_payload)

        page.links_with(href: @inner_pages).each do |link|
          next if link.href =~ /\.(mp4|pdf|png|docx|jpg|jpeg|zip)|\/activity$/
          next if link.href =~ /\/(cdn-cgi|static)\//
          next if link.href =~ /\/(archive|blob|tree|tags|keywords|stargazers|activity|actions?|commit|issues?|milestones|pull)\// # github related

          url = build_url(link.href)
          spider.enqueue(url) if url
        end
        metadata
      end

      def build_url url
        case url.to_s
        when '/' then @root
        when /^https?:\/\// then normalize_url(url.to_s)
        when /^\/[^\/]/ then normalize_url(@root + url.to_s)
        else normalize_url(url)
        end
      end

      def normalize_url url
        return nil if url.nil?
        if !@path.empty? && url.start_with?(@path)
          
          require "pry";binding.pry 
          url = @root.sub(@path, url)
        elsif url.start_with?("/")
          url = @root + url
        elsif url.include?(" ") || url.include?("?")
          begin
            url = URI.decode_www_form(url)[0][0]
            uri = URI.parse(url)

            uri.normalize!
            uri.query = nil
            final = uri.to_s.gsub(/[\?#].+$/,'')
            url.include?(' ') ? url_encode(final) : final
          rescue URI::InvalidURIError, ArgumentError
            url && url.split("?").first || url
          end
        else
          url
        end
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
  end
end
