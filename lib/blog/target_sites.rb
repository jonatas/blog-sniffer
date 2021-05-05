module Blog
  module TargetSites
    module_function
    SOURCE = "https://raw.githubusercontent.com/kilimchoi/engineering-blogs/master/engineering_blogs.opml"
    def all_urls
      @all_urls ||=
        begin
          page = Blog::Agent.get(SOURCE)
          xml = Nokogiri.parse(page.body)
          xml.xpath("//@htmlUrl").map(&:value)
        end
    end

  end
end
