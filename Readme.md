Ruby Regex Timeout / Backtracking Bomb Safety

Don't let untrusted regular expressions kill your servers (cannot be caught with a `Timeout`).

DEPRECATED: Ruby 3.2+ [supports this natively](https://www.ruby-lang.org/en/news/2022/04/03/ruby-3-2-0-preview1-released/)

Install
=======

```Bash
gem install safe_regexp
```

Usage
=====

```Ruby
# normal
/a/.match?('a') # -> true in 0.0001ms
SafeRegexp.execute(/a/, :match?, 'a') # -> true in 0.13568ms

# bomb
require "safe_regexp"
regex = /aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?/
value = "a" * 46
regex.match? value # false in ~60s
SafeRegexp.execute(regex, :match?, value) # -> SafeRegexp::RegexpTimeout

# methods without arguments
regex = "^(The '(?<first_group>.*)' parameter of the (?<second_group>.*))$"
SafeRegexp.execute(regex, :names) # -> ["first_group", "second_group"]
```

Behind the scenes
=================

 - not using `Thread` or `Timeout`
 - spawns a co-processor and `kill -9` it if it takes too long, shuts down after 10s of not being used (to avoid process boot cost), use `keepalive: 0` to shutdown immediately
 - defaults to 1s timeout
 - uses 1 co-processor per thread
 - any `MatchData` object is returned as Array since it cannot be dumped

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/safe_regexp.png)](https://travis-ci.org/grosser/safe_regexp)
