Backtracking bomb safety / timeouts for regular expressions

Install
=======

```Bash
gem install safe_regexp
```

Usage
=====

```Ruby
/a/.match?('a') # -> true in 0.0001ms
SafeRegexp.execute(/a/, :match?, 'a') # -> true in 0.13568ms

require "safe_regexp"
regex = /aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?/
value = "a" * 46
regex.match? value # false in ~60s
SafeRegexp.execute(regex, :match?, value) # -> SafeRegexp::RegexpTimeout
```

Behind the scenes
=================

 - spawns a co-processor and `kill -9` it if it takes too long, shuts down after 10s of not being used, use `keepalive: 0` to shutdown immediately
 - defaults to 1s timeout
 - uses 1 co-processor per thread

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/safe_regexp.png)](https://travis-ci.org/grosser/safe_regexp)
