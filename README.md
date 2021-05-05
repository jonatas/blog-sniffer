# Blog::Sniffer

It allows you to fetch information from all engineering blog posts and save it
in a hypertable.

## Installation

It's not a rubygem yet, so you need to clone and install locally:

```bash
git clone git@github.com:jonatas/blog-sniffer.git
cd blog-sniffer
bundle install
```

Setup your micro instance on [Timescale for free](https://www.timescale.com/timescale-signup).
Then you can configure your PG_URI or make it local.

```
export PG_URI="postgres://<user>:<password>@<host>:<port>/tsdb?sslmode=require"
```

Then you can use `bin/blog-sniffer *<urls>` to start crawling or simply:

```bash
bin/blog-sniffer
```

It will sniff all websites over [lib/blog/target_sites](lib/blog/target_sites.rb) that is fetching everything
from this [repo](https://github.com/kilimchoi/engineering-blogs).

## Usage

Check [bin/blog-sniffer](bin/blog-sniffer) to get more details in a massive
crawling system, but the basics are:


Run `bin/console` to get the classes loaded into a pry session:

```ruby
[1] pry(main)> spider = Blog::Sniffer::EngineeringDocs.new(root: "https://blog.timescale.com")
=> #<Blog::Sniffer::EngineeringDocs:0x00007fcdbc26dae0 @root="https://blog.timescale.com">
[2] pry(main)> spider.results.lazy.take(1).first
Handling  : "https://blog.timescale.com"
=> {:title=>"Timescale Blog",
 :headers=>
  ["$40 million to help developers measure everything that matters",
   "Timescale Newsletter Roundup: March 2021 Edition", ....],
 :links=>
  {["Products"]=>"https://www.timescale.com/products",
   ["Docs"]=>"https://docs.timescale.com",
   ["Blog"]=>"https://blog.timescale.com/",
   ["Log into Timescale Cloud"]=>"https://portal.timescale.cloud/login",
   ["Log into Timescale Forge"]=>"https://console.forge.timescale.com/",
   ["Try for free"]=>"https://www.timescale.com/timescale-signup", ...}
 :body=>
  [ "We're excited to announce that we've a raised $40M Series B, ...", ...]
 :html_size=>135963,
 :time_to_fetch=>2.063971000025049,
 :url=>"https://blog.timescale.com"}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies.

It does not contain any spec as I wrote it as a POC. Feel free to contribute and
add them ;)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jonatas/blog-sniffer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/blog-sniffer/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Blog::Sniffer project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/blog-sniffer/blob/master/CODE_OF_CONDUCT.md).
