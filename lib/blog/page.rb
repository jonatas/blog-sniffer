require 'timescaledb'

module Blog
  class Page < Timescaledb::ApplicationRecord
    acts_as_hypertable time_column: :time, segmentby_column: :url

    before_save :cleanup

    def cleanup
      self.time = Time.now
      self.headers = self.headers.grep(/\w+/).uniq
      self.links.delete_if {|k,v| k !~ /^\w+/ || v =~ /^[\/#]/}
    end

    def self.create_hypertable_if_not_exists!
      ActiveRecord::Base.establish_connection(ENV['PG_URI'])
      unless self.table_exists?
        hypertable_options = {
          time_column: 'time',
          chunk_time_interval: '1 day',
        }

        connection.instance_exec do
          create_table(:pages, id: false, hypertable: hypertable_options) do |t|
            t.timestamptz :time, null: false
            t.text :url, null: false
            t.float :time_to_fetch
            t.text :title, null: false
            t.text :headers, array: true, default: []
            t.jsonb :links
            t.text :body, array: true, default: []
            t.text :codeblocks, array: true, default: []
            t.integer :html_size
          end
        end
      end
    end
  end
end
