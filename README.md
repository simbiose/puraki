# summary

puraki is a worker(s) manager written in pure [Lua](http://www.lua.org/) on top of [Luvit](http://luvit.io/).

# WTF puraki means?

puraki means "to work" in [nheengatu](http://en.wikipedia.org/wiki/Nheengatu_language)

# help and support

please fill an issue or help it doing a clone and then a pull request

# license

[BEER-WARE](http://en.wikipedia.org/wiki/Beerware), see source
  
# basic usage

```lua

    local worker, set_timeout = 
      require('puraki').new(), require('timer').setTimeout

    worker.parallel = 20
    worker.interval = 1000

    -- each task is a closure, configure metadata, return a task to do, ...
    worker:task(
      function(this, meta)

        meta.ttl   = 0
        meta.times = 0

        local function task(metadata)
          metadata.times = metadata.times + 1
          p(metadata.task, metadata.times)

          return (metadata.times > metadata.task)
        end

        return task
      end)

    worker:run()

    set_timeout(2000, function()
        p('stop queue')
        worker:stop()
      end)

    set_timeout(4000, function() 
        p('resume queue')
        worker:resume()
      end)
```

# test

... in progress

# TODO

+ "kill" coroutines when idle, simulate error
+ create a test suite
+ create a rockspec
+ create a wiki?

% November 16th, 2013 -03 GMT