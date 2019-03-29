Ruby Regex Timeout / Backtracking Bomb Safety

Don't let untrusted regular expressions kill your servers (cannot be caught with a `Timeout`).

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
```

Behind the scenes
=================

 - not using `Thread` or `Timeout`
 - spawns a co-processor and `kill -9` it if it takes too long, shuts down after 10s of not being used, use `keepalive: 0` to shutdown immediately
 - defaults to 1s timeout
 - uses 1 co-processor per thread
 - any `MatchData` object is returned as Array since it cannot be dumped

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/safe_regexp.png)](https://travis-ci.org/grosser/safe_regexp)
