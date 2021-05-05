require 'active_record'

module Blog
  class Page < ActiveRecord::Base
    self.primary_key = :url

    before_save :cleanup

    def cleanup
      self.time = Time.now
      self.headers = self.headers.grep(/\w+/).uniq
      self.links.delete_if {|k,v| k !~ /^\w+/ || v =~ /^[\/#]/}
    end

    def self.create_hypertable_if_not_exists!
      ActiveRecord::Base.establish_connection(ENV['docs_uri'])
      unless self.table_exists?
        self.connection.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS pages (
            time TIMESTAMPTZ NOT NULL,
            url text,
            time_to_fetch real,
            title text,
            headers text[],
            links jsonb,
            codeblocks text[],
            body text[],
            html_size integer);

          SELECT create_hypertable('pages', 'time');
        SQL
      end
    end
  end
end
