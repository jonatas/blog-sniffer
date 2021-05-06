# Blog::Sniffer

It allows you to fetch information from all engineering blog posts from 
[this list](https://github.com/kilimchoi/engineering-blogs)(https://github.com/kilimchoi/engineering-blogs)
and save it in a database for further analysis.

## Why?

I was just building a small fuzzy finder to get urls from blog content to easily
access content while I'm learning about Timescale.

I'd like to have a fuzzy finder to easy find [posts](https://blog.timescale.com)
or [docs](https://docs.timescale.com) from timescale. Validating if all internal
links are working and so on...

Then, I thought...

1. I'm getting more deep on technical writing and my objective is better understand the
industry language and the jargons. I'd like to play with this data and have fun
with statistics related to text writing.

2. I'm also very interested in data science and I'd like to explore all the data in different ways.

3. I'm benchmarking the smallest instance that [forge](https://www.timescale.com/forge) can offer :wink:.

## Installation

It's not a rubygem yet, so you need to clone and install locally:

```bash
git clone git@github.com:jonatas/blog-sniffer.git
cd blog-sniffer
bundle install
```

Setup your micro instance on [Timescale for free](https://www.timescale.com/timescale-signup).
Then you can configure your PG_URI through your favorite manner to have access
to the environment variable. 

```
export PG_URI="postgres://<user>:<password>@<host>:<port>/tsdb?sslmode=require"
```

I try to use [direnv](https://direnv.net) make my life easier and safe.
So, I can drop my secrets into a `.envrc` and it will be available only in this directory:

```bash
echo 'export PG_URI="postgres://<user>:<password>@<host>:<port>/tsdb?sslmode=require"' >> .envrc
direnv allow
```

Then you can use `bin/blog-sniffer *<urls>` to start crawling or simply take
over the world!

```bash
bin/blog-sniffer
```

It will sniff all websites over [lib/blog/target_sites](lib/blog/target_sites.rb) that is fetching everything
from this [repo](https://github.com/kilimchoi/engineering-blogs). To run over all repo list it took over 24 hours to me.

Around 200k pages.

You can open and run parallel process and it will keep expanding and fetching
more URLs. The modem of my house got stuck after hours parallelizing 10 process,
but it uses a low band and memory.

A few tabs in parallel is enough. In 10+ hours I got 32k pages downloaded.

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

## Getting familiar with the Postgresql Text Search Controls

Getting a ranked titles using [text search controls](https://www.postgresql.org/docs/13/textsearch-controls.html).

```sql
SELECT title, ts_rank_cd(to_tsvector(title), query) AS rank
FROM pages, to_tsquery('petabyte+scale') query
WHERE query @@ to_tsvector(title)
ORDER BY rank DESC
LIMIT 10;
```

Now let's wrap it on a function, that was one of my objectives:
```sql
CREATE TYPE ranked_post AS (title text, url text, rank real);

CREATE FUNCTION get_ranked_posts(text, integer default 5) RETURNS setof ranked_post
  AS $$
    SELECT title, url, ts_rank_cd(to_tsvector(title), query) AS rank
    FROM pages, to_tsquery($1) query
    WHERE query @@ to_tsvector(title)
    ORDER BY rank DESC
    LIMIT $2;
$$
LANGUAGE SQL;
```

Trying it;

```sql
select rank, title from get_ranked_posts('postgresql+scaling');
 rank |                   title
------+--------------------------------------------
  0.1 | How to Scale PostgreSQL 10
 0.05 | Upgrading PostgreSQL At Scale - 5 min read
 ...
```

Testing different queries with different limit:

```sql
select rank, url from get_ranked_posts('Analytical+Platform',7) ;
 rank |                                                             url
------+------------------------------------------------------------------------------------------------------------------------------
  0.1 | https://eng.uber.com/logging/#respond
  0.1 | https://blog.timescale.com/blog/promscale-analytical-platform-long-term-store-for-prometheus-combined-sql-promql-postgresql/
  0.1 | https://blogs.nvidia.com/blog/2020/06/24/apache-spark-gpu-acceleration/?nv_excludes=45965,45983
  0.1 | https://blog.timescale.com/blog/promscale-analytical-platform-long-term-store-for-prometheus-combined-sql-promql-postgresql/
  0.1 | https://eng.uber.com/logging/
  0.1 | https://eng.uber.com/athenax/
  0.1 | https://blog.cloudera.com/why-an-integrated-analytics-platform-is-the-right-choice/
(7 rows)
```

Some results are still repeated as I didn't have the proper time to normalize
all the urls before fetch it. Feel free to contribute :raised_hands:

Exploring pages per domain:

```sql
select split_part(url,'/',3),count(1) from pages group by 1 order by 2 desc limit 10;
       split_part        | count
-------------------------+-------
 medium.com              | 22132
 tech.lendinghome.com    |  2000
 www.stackabuse.com      |  1998
 blog.codinghorror.com   |  1992
 www.drivenbycode.com    |  1989
 engblog.nextdoor.com    |  1988
 sitepoint.com           |  1986
 snyk.io                 |  1942
 engineroom.teamwork.com |  1859
 blog.fedecarg.com       |  1842
(10 rows)
```

Let's check the worst scenarios we had fetching the data from websites:

```sql
select split_part(url,'/',3) as domain, avg(time_to_fetch) from pages group by 1 order by 2 desc limit 10;
               domain                |        avg
-------------------------------------+--------------------
 michaelcrump.net                    |  64.85552978515625
 adventuresinautomation.blogspot.com |  8.075942993164062
 www.billthelizard.com               |  5.909573554992676
 www.confluent.io                    |  4.935941823245434
 blog.lerner.co.il                   |  4.742450714111328
 haptik.ai                           |  4.613358974456787
 www.raizlabs.com                    |  4.457476615905762
 code.mixpanel.com                   | 4.2434492111206055
 www.future-processing.pl            |  4.072421073913574
 blog.blundellapps.co.uk             | 3.5754189491271973
(10 rows)
```

## Slowest websites

> Note that these are the slowest websites considering I did it from my home 🇧🇷

```sql
 select split_part(url,'/',3) as domain,count(1) as total_pages, avg(time_to_fetch) as avg_time_to_fetch, sum(time_to_fetch) as total_time, pg_size_pretty(sum(html_size)) as bandwidth from pages group by 1 order by 3 desc limit 10;
               domain                | total_pages | avg_time_to_fetch  | total_time | bandwidth
-------------------------------------+-------------+--------------------+------------+-----------
 michaelcrump.net                    |           1 |  64.85552978515625 |   64.85553 | 16 kB
 adventuresinautomation.blogspot.com |           1 |  8.075942993164062 |   8.075943 | 1203 kB
 www.billthelizard.com               |           1 |  5.909573554992676 |  5.9095736 | 319 kB
 www.confluent.io                    |          89 |  4.935941823245434 |  439.29883 | 63 MB
 blog.lerner.co.il                   |           1 |  4.742450714111328 |  4.7424507 | 92 kB
 haptik.ai                           |           1 |  4.613358974456787 |   4.613359 | 33 kB
 www.raizlabs.com                    |           1 |  4.457476615905762 |  4.4574766 | 40 kB
 code.mixpanel.com                   |           1 | 4.2434492111206055 |   4.243449 | 298 kB
 www.future-processing.pl            |           1 |  4.072421073913574 |   4.072421 | 87 kB
 blog.blundellapps.co.uk             |           1 | 3.5754189491271973 |   3.575419 | 17 kB
```

## What domains we spend more time crawling

```sql
select split_part(url,'/',3) as domain,count(1) as total_pages, avg(time_to_fetch) as avg_time_to_fetch, sum(time_to_fetch) as total_time, pg_size_pretty(sum(html_size)) as bandwidth from pages group by 1 order by 4 desc limit 10;
        domain        | total_pages | avg_time_to_fetch  | total_time | bandwidth
----------------------+-------------+--------------------+------------+-----------
 medium.com           |       22132 | 0.7525404742870937 |   16655.22 | 4201 MB
 www.stackabuse.com   |        1998 |  1.159109460268248 |  2315.9016 | 247 MB
 auth0.com            |         988 |  2.012826143126739 |  1988.6725 | 130 MB
 lambda.grofers.com   |         989 |  1.795852951238382 |  1776.0988 | 196 MB
 engblog.nextdoor.com |        1988 | 0.8649827361601579 |  1719.5862 | 297 MB
 www.adamtuliper.com  |         965 | 1.7380711382689253 |  1677.2385 | 192 MB
 www.cimgf.com        |         856 |  1.952296660429685 |  1671.1658 | 32 MB
 sitepoint.com        |        1986 | 0.8376746205228484 |  1663.6222 | 254 MB
 team.goodeggs.com    |         891 | 1.7691494242594432 |   1576.312 | 117 MB
 snyk.io              |        1942 | 0.7906604430357227 |  1535.4626 | 146 MB
```

If you reached the end of the analyzes with me, please leave a star and
contribute!

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jonatas/blog-sniffer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/jonatas/blog-sniffer/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Blog::Sniffer project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/blog-sniffer/blob/master/CODE_OF_CONDUCT.md).
