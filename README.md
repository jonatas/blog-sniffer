# Blog::Sniffer

It allows you to fetch information from all engineering blog posts from 
[this list](https://github.com/kilimchoi/engineering-blogs)
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
from this [repo](https://github.com/kilimchoi/engineering-blogs). To run over all repo list it took ~19 hours to me. Around 200k pages.

You can open and run parallel process and it will keep expanding and fetching
more URLs. The modem of my house got stuck after hours parallelizing 10 process,
but it uses a low band and memory.

A few tabs in parallel is enough. In 10+ hours I got 32k pages downloaded.

So, let's explain this journey using SQL, so, you can better understand the
results.

## State of art

I downloaded `228849` pages in `19 hours` from my home :)

```sql
 SELECT MIN(time) AS start,
   MAX(time) AS end,
   COUNT(1) AS total_pages,
   EXTRACT(EPOCH FROM(MAX(time) - MIN(time)) / 3600)::INTEGER AS hours_of_adventure
   FROM pages;
            start             |              end              | total_pages | hours_of_adventure
------------------------------+-------------------------------+-------------+--------------------
 2021-05-05 19:05:43.54879+00 | 2021-05-06 14:05:51.156821+00 |      228849 |                 19
```

But, I haven't worked all the day and have paused it for several hours, so,
let's have a look on the total pages downloaded per hour.

I'll use [time_bucket](https://docs.timescale.com/api/latest/analytics/time_bucket/) function.

```sql
 SELECT time_bucket('1 hour', time) AS hour,
   COUNT(1) AS total_pages,
   pg_size_pretty(SUM(html_size)) AS bandwidth
   FROM pages
   GROUP BY 1;
          hour          | total_pages | bandwidth
------------------------+-------------+-----------
 2021-05-05 19:00:00+00 |        8154 | 1083 MB
 2021-05-05 20:00:00+00 |         890 | 154 MB
 2021-05-05 21:00:00+00 |        7818 | 1039 MB
 2021-05-05 22:00:00+00 |           8 | 164 kB
 2021-05-06 00:00:00+00 |         340 | 19 MB
 2021-05-06 01:00:00+00 |         500 | 26 MB
 2021-05-06 02:00:00+00 |        1828 | 358 MB
 2021-05-06 03:00:00+00 |        8773 | 808 MB
 2021-05-06 04:00:00+00 |       15926 | 1971 MB
 2021-05-06 05:00:00+00 |       18978 | 2543 MB
 2021-05-06 06:00:00+00 |       19905 | 2485 MB
 2021-05-06 07:00:00+00 |       22292 | 3111 MB
 2021-05-06 08:00:00+00 |       22141 | 3429 MB
 2021-05-06 09:00:00+00 |       21836 | 1962 MB
 2021-05-06 10:00:00+00 |       18465 | 2026 MB
 2021-05-06 11:00:00+00 |       24662 | 1549 MB
 2021-05-06 12:00:00+00 |       19350 | 1935 MB
 2021-05-06 13:00:00+00 |       16653 | 1722 MB
 2021-05-06 14:00:00+00 |         330 | 12 MB
```

If you clicked in the link before, maybe you would like to get to know more
about `time_bucket` and build an amazing query for it:

```sql
SELECT url FROM pages WHERE title ~ 'time_bucket';
                                               url
--------------------------------------------------------------------------------------------------
 https://docs.timescale.com/api/latest/analytics/time_bucket/
 https://docs.timescale.com/api/latest/analytics/time_bucket_gapfill/
 https://blog.timescale.com/blog/simplified-time-series-analytics-using-the-time_bucket-function/
(3 rows)
```

## Where the information comes from?

Counting pages per host. Extracting domain would be a bit more complicated, but
here we can have a good overview of the most richful sources.

```sql
SELECT SPLIT_PART(url,'/',3) as host, COUNT(1) FROM pages GROUP BY 1 ORDER BY 2 DESC LIMIT 10;
       host              | count
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

## Exploring dynamic content

What if I reload  the page and the title of the website changed?
Let's discover who is doing that:

```sql
SELECT url, ARRAY_AGG(title)
FROM pages
GROUP BY 1 HAVING COUNT(DISTINCT title) > 1
ORDER BY COUNT(DISTINCT title) DESC LIMIT 10;
                     url                      |                                                        array_agg
----------------------------------------------+-------------------------------------------------------------------------------------------------------------------------
 http://blog.honeybadger.io/                  | {"Honeybadger Developer Blog","Exception and Uptime Monitoring for Application Developers - Honeybadger"}
 http://blog.mandrill.com/                    | {"All-In-One Integrated Marketing Platform for Small Business","What is Transactional Email?"}
 http://devblog.coolblue.nl/                  | {"DEV Community 👩‍💻👨‍💻","Coolblue - DEV Community"}
 http://facebook.github.io/react-native/blog/ | {"React Native · Learn once, write anywhere","Blog · React Native"}
 http://jakewharton.com/blog                  | {"Jake Wharton","Posts - Jake Wharton"}
 http://jlongster.com/archive                 | {"James Long","All Posts"}
 http://multithreaded.stitchfix.com/blog/     | {"Stitch Fix Technology – Multithreaded","Blog | Stitch Fix Technology – Multithreaded"}
 http://rocksdb.org/blog                      | {"GitHub Documentation","Blog | RocksDB"}
 http://www.boxever.com/blog/                 | {"Boxever Digital Optimisation Platform","Boxever Insights","Boxever Digital Optimisation Platform","Boxever Insights"}
 http://blog.faraday.io/                      | {"AI for B2C growth | Faraday AI","The Faraday Blog"}
(10 rows)
```
Funny, no? :smile:

## Getting familiar with the Postgresql Text Search Controls

Getting a ranked titles using [text search controls](https://www.postgresql.org/docs/13/textsearch-controls.html).

Let's start with `to_tsvector`:

```
SELECT title, to_tsvector(title) FROM pages WHERE url ~ 'hypertable' LIMIT 5;
                  title                   |                  to_tsvector
------------------------------------------+-----------------------------------------------
 Distributed Hypertables | Timescale Docs | 'distribut':1 'doc':4 'hypert':2 'timescal':3
 ALTER | Timescale Docs                   | 'alter':1 'doc':3 'timescal':2
 DROP | Timescale Docs                    | 'doc':3 'drop':1 'timescal':2
 CREATE | Timescale Docs                  | 'creat':1 'doc':3 'timescal':2
 Hypertables & Chunks | Timescale Docs    | 'chunk':2 'doc':4 'hypert':1 'timescal':3
(5 rows)
```

Now, let's use `to_tsquery` with `@@` operator to combine queries over vectors:

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

Trying it:

```sql
select rank, title from get_ranked_posts('postgresql+scaling');
 rank |                   title
------+--------------------------------------------
  0.1 | How to Scale PostgreSQL 10
 0.05 | Upgrading PostgreSQL At Scale - 5 min read
 ...
```

Testing a different subject with another limit:

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

Now, achieving one of my challenges to get the top posts I want from Timescale
blog or docs:

```sql
CREATE OR REPLACE FUNCTION get_ts_url_for(text, integer default 5) RETURNS setof ranked_post
  AS $$
    SELECT title, url,
    ts_rank_cd(to_tsvector(title), query) + ts_rank_cd(to_tsvector(url), query) AS rank
    FROM pages, plainto_tsquery('english', $1) query
    WHERE url ~ '^https://(blog|docs).timescale.com'
      AND (query @@ to_tsvector(title) OR query @@ to_tsvector(url))
    ORDER BY rank DESC
    LIMIT $2;
$$
LANGUAGE SQL;
```

Running it, the timing is not very satisfatory:

```sql
\timing
tsdb=> select distinct url from get_ts_url_for('hypertable', 10);
...
Time: 2200.911 ms (00:02.201)
```

Let's create a materialized view to only get timescale content preprocessing the
vector we're going to use for the search and limiting the scope to the domain we
want:

```sql
DROP MATERIALIZED VIEW timescale_content;
 CREATE MATERIALIZED VIEW timescale_content AS
    SELECT title, url,
      to_tsvector(regexp_replace(url, '[^\w]+', ' ', 'gi') || title) AS search_vector
    FROM pages
    WHERE url ~ '^https://(blog|docs).timescale.com';
SELECT 960
Time: 2817.970 ms (00:02.818)
```
Now, let's rewrite the `get_ts_url_for` function to use the previous view that
will limit the search and use pre-processed ts_vector combining `url`, `title`
and `headers`.

```sql
CREATE OR REPLACE FUNCTION get_ts_url_for(text, integer default 5) RETURNS setof ranked_post
  AS $$
    SELECT title, url,
    ts_rank_cd(search_vector, query) AS rank
    FROM timescale_content, plainto_tsquery('english', $1) query
    WHERE query @@ search_vector
    ORDER BY rank DESC
    LIMIT $2;
$$
LANGUAGE SQL;
CREATE FUNCTION
Time: 388.378 ms
```

Now, let's see the timing for the same query:

```sql
select distinct url from get_ts_url_for('hypertable', 10);        https://docs.timescale.com/timescaledb/latest/overview/release-notes/changes-in-timescaledb-2/#caggs
... 
Time: 297.890 ms
```

7 times faster :tada:


And I use fish shell, so, I'll write a short script to easily get it from the
command line:

```fish
set -gx docs_uri "postgres://<user>:<pass>@<host>:<port>/<dbname>?sslmode=require"

function ts_url --description "Get URL searching on timescale docs"
  set query "select distinct url from get_ts_url_for('$argv', 10);"
  psql $docs_uri -c "$query"
end
```

And, loading it in my fish sources, I can use:


```bash
ts_url hypertable
                                              url
-----------------------------------------------------------------------------------------------
 https://docs.timescale.com/timescaledb/latest/overview/core-concepts/distributed-hypertables/
 https://docs.timescale.com/timescaledb/latest/getting-started/create-hypertable/
 https://docs.timescale.com/timescaledb/latest/how-to-guides/schema-management/alter/
 https://docs.timescale.com/timescaledb/latest/how-to-guides/hypertables/
 https://docs.timescale.com/api/latest/distributed-hypertables/create_distributed_hypertable/
 https://docs.timescale.com/timescaledb/latest/overview/core-concepts/hypertables-and-chunks/
 https://docs.timescale.com/api/latest/hypertable/
 https://docs.timescale.com/api/latest/hypertable/hypertable_size/
 https://docs.timescale.com/timescaledb/latest/how-to-guides/distributed-hypertables/
 https://docs.timescale.com/api/latest/hypertable/create_hypertable/
```

Now, let's explore a bit of the power of the ts search:

```bash
ts_url hypertable drop
                                            url
-------------------------------------------------------------------------------------------
 https://docs.timescale.com/timescaledb/latest/how-to-guides/hypertables/drop/
 https://docs.timescale.com/timescaledb/latest/how-to-guides/distributed-hypertables/drop/
 https://docs.timescale.com/api/latest/hypertable/drop_chunks/
(3 rows)
```

Let's get deep and select only `drop+chunks`:


```bash
⋊> ~ ts_url hypertable drop chunk                                                                                               11:25:39
                              url
---------------------------------------------------------------
 https://docs.timescale.com/api/latest/hypertable/drop_chunks/
(1 row)
```

If we revert the order of the words it should still work:

```bash
⋊> ~ ts_url hypertable chunk drop                                                                                               11:25:53
                              url
---------------------------------------------------------------
 https://docs.timescale.com/api/latest/hypertable/drop_chunks/
(1 row)
```

Reverting the order of all words in the content:

```bash
⋊> ~ ts_url chunk drop  hypertable                                                                                              11:26:03
                              url
---------------------------------------------------------------
 https://docs.timescale.com/api/latest/hypertable/drop_chunks/
(1 row)
```

It's really working :dancers:

Now, let's create one more shortcut to also copy the top ranked link to the clipboard:

```fish
function ccc_url --description "Copy top URL searching on timescale docs"
  set query "select distinct url from get_ts_url_for('$argv', 1);"
  psql $docs_uri -c "$query"  | tail -n 3 | head -n 1| pbcopy
end
```

## Most common words

We can use [ts_stat](https://www.postgresql.org/docs/current/textsearch-features.html)
to get the top most used words:

```sql
SELECT *
FROM ts_stat($$SELECT to_tsvector('english', title) FROM pages$$)
ORDER BY ndoc DESC
LIMIT 10;
   word   | ndoc  | nentry
----------+-------+--------
 blog     | 34361 |  35065
 medium   | 26995 |  27182
 engin    | 23974 |  25833
 facebook | 14594 |  16400
 page     | 12717 |  12740
 develop  | 11512 |  12237
 use      |  6374 |   6522
 tech     |  6373 |   6617
 code     |  6353 |   6602
 archiv   |  5442 |   5568
(10 rows)
```
And also reuse our `timescale_content` view to check the statistics only of
timescale content:

```sql
SELECT *
FROM ts_stat($$SELECT search_vector FROM timescale_content$$)
ORDER BY ndoc DESC
LIMIT 10;
    word     | ndoc | nentry
-------------+------+--------
 https       |  960 |    960
 timescal    |  960 |   1761
 com         |  957 |    957
 blog        |  486 |   1046
 timescaledb |  483 |    671
 doc         |  474 |    947
 latest      |  472 |    473
 data        |  204 |    343
 guid        |  196 |    198
 time        |  192 |    347
(10 rows)
```

Some results are still repeated as I didn't have the proper time to normalize
all the urls before fetch it. Feel free to contribute :raised_hands:

## Worst Scenarios fetching data

Let's check the average time to download a page grouped by domain:

```sql
SELECl SPLIT_PART(url,'/',3) AS domain, AVG(time_to_fetch) FROM pages GROUP BY 1 ORDER BY 2 DESC LIMIT 10;
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
SELECT SPLIT_PART(url,'/',3) AS domain, COUNT(1) as total_pages,
  AVG(time_to_fetch) AS avg_time_to_fetch,
  SUM(time_to_fetch) AS total_time,
  PG_SIZE_PRETTY(SUM(html_size)) AS bandwidth
FROM pages
GROUP BY 1 ORDER BY 3 DESC LIMIT 10;
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

## Where the crawler spent the time

```sql
SELECT SPLIT_PART(url,'/',3) AS domain, COUNT(1) AS total_pages,
  AVG(time_to_fetch) AS avg_time_to_fetch,
  SUM(time_to_fetch) AS total_time,
  PG_SIZE_PRETTY(SUM(html_size)) AS bandwidth
FROM pages
GROUP BY 1 ORDER BY 4 DESC LIMIT 10;

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

## How many pages got duplicated with links redirection?

I was trying to understand several pages generates '----' in the URL, so I
decided to inspect it a bit:

```sql
select url from pages where url ~ '-------' limit 5;
                                                                                      url
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 https://...8d7f8425882?source=collection_home---4------0-----------------------
 https://...821168da?source=collection_home---4------1-----------------------
 https://...apache-flink-723ce072b7d2?source=collection_home---4------2-----------------------
 https://...g-data-hub-ba2605558883?source=collection_home---4------3-----------------------
 https://...1f3d87def1?source=collection_home---4------4-----------------------
```
I just reduced the urls to make it more visible what I mean.

So  I thought about double checking how many duplications I got just because of
the extra params I have, so let's understand the picture:

```sql
select count(url) from pages where url ~ '-------' ;
 count
-------
 33296
(1 row)
```
Wow, almost 15% of the data.

Now, let's count how many full duplicates we have:
```sql
tsdb=> select count(distinct url) from pages where url ~ '-------' ;
 count
-------
 30668
(1 row)
```

Normalizing the urls ignoring all params to check how many real sources we have:

```sql
select count(distinct split_part(url,'?',1)) from pages where url ~ '-------';
 count
-------
 12173
(1 row)
```
Now, confirming how many of this pages are the root pages of this 30k cases:

```sql
WITH normalized_urls AS (
  SELECT DISTINCT SPLIT_PART(url,'?',1) AS url
  FROM pages
  WHERE url ~ '-------' 
)
SELECT COUNT(1) FROM pages WHERE url IN (SELECT url FROM normalized_urls);
```

Interesting: 10% of the pages are fully URLs with different parameters!
`:iseewhatyoudidthere:`.


## What are the most used words in the titles?

```sql
WITH words AS ( SELECT REGEXP_SPLIT_TO_TABLE(title, E'\\W+') AS word FROM pages)
SELECT word, count(*) FROM words
WHERE LENGTH(word) > 5 -- Just to skip in, on, at, etc
GROUP BY 1 ORDER BY 2 DESC limit 10;
    word     | count
-------------+-------
 Medium      | 27117
 Engineering | 21363
 Facebook    | 16398
 Archives    |  4287
 Developer   |  4180
 Cloudflare  |  3976
 Google      |  3545
 Software    |  3282
 Product     |  3157
 Protection  |  3138
```

## What are the most common call to action in the bottom of tutorial pages?

```sql
SELECT headers[array_length(headers,1)], count(1)
FROM pages
WHERE title ~ 'tutorial'
AND ARRAY_LENGTH(headers,1) > 1
GROUP BY 1 ORDER BY 2 DESC LIMIT 5;
       headers        | count
----------------------+-------
 Share your thinking. |    25
 Popular posts        |    18
 Tags                 |    12
 Books I've written   |     9
 Other                |     7
(5 rows)
```

## What are the most common call to action in the bottom of any page?

```
 select headers[array_length(headers,1)], count(1) from pages where array_length(headers,1) > 1 group by 1 order by 2 desc limit 10;
          headers           | count
----------------------------+-------
 Share your thinking.       | 15790
 RELATED CATEGORIES         |  8473
 Resources                  |  3212
 Connect                    |  3067
 Meta                       |  3064
 Tags                       |  2815
 Post navigation            |  2753
 Categories                 |  2745
 Leave a Reply Cancel reply |  2718
 RSS                        |  2246
(10 rows)
```

## Most common words

Let's explore the most common words in the Timescale domain:

```sql
WITH words AS ( SELECT REGEXP_SPLIT_TO_TABLE(title, E'\\W+') AS word FROM pages WHERE url ~ 'timescale.com')
SELECT word, count(*) FROM words where LENGTH(word) > 5 GROUP BY 1 ORDER BY 2 DESC limit 10;
    word     | count
-------------+-------
 Timescale   |   583
 TimescaleDB |   130
 series      |   111
 PostgreSQL  |    76
 database    |    56
 Series      |    42
 Create      |    41
 Grafana     |    37
 Database    |    33
 Building    |    29
 ```

 As you can see we're not normalizing the words, so, let's `LOWER` them to unify the duplicated words:

 ```sql
 tsdb=> WITH words AS ( SELECT REGEXP_SPLIT_TO_TABLE(LOWER(title), E'\\W+') AS word FROM pages WHERE url ~ 'timescale.com')
SELECT word, count(*) FROM words where LENGTH(word) > 5 GROUP BY 1 ORDER BY 2 DESC limit 10;
    word     | count
-------------+-------
 timescale   |   583
 series      |   153
 timescaledb |   134
 database    |    89
 postgresql  |    76
 create      |    45
 grafana     |    37
 building    |    32
 continuous  |    28
 aggregates  |    26
(10 rows)
```

Some common words from facebook engineering headers:

```sql
WITH words AS ( SELECT REGEXP_SPLIT_TO_TABLE(headers::text, E'\\W+') AS word FROM pages WHERE url ~ 'engineering.fb.com')
SELECT word, count(*) FROM words where LENGTH(word) > 5 GROUP BY 1 ORDER BY 2 DESC limit 10 offset 30;
    word     | count
-------------+-------
 production  |    50
 center      |    50
 better      |    47
 Networking  |    46
 efficient   |    46
 software    |    46
 analysis    |    45
 approach    |    45
 Introducing |    43
 hardware    |    43
(10 rows)
```

If you reached the end of the analyzes with me, please, go ahead and try it
yourself! Contribute with any insights you have :)

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

Bug reports and pull requests are welcome on GitHub at https://github.com/jonatas/blog-sniffer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/jonatas/blog-sniffer/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Blog::Sniffer project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/blog-sniffer/blob/master/CODE_OF_CONDUCT.md).
