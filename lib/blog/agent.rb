
module Blog
  module Agent
    module_function
    def get url
      instance.get url
    end
    def instance
      @agent ||= Mechanize.new { |a|
        a.post_connect_hooks << lambda { |_,_,response,_|
          if response.content_type.nil? || response.content_type.empty?
            response.content_type = 'text/html'
          end
        }
      }
    end
  end
end
