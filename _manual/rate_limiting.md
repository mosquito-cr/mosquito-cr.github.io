---
layout: manual
title: Rate Limiting Jobs
toc: false
---

Optionally, Jobs can be rate limited to limit the number of tasks that get executed within a given period of time.

For example, if 10 messages were enqueued for ThrottledJob at one time; 5 would be executed immediately, then pause for a minute, then execute the next 5.

```crystal
class ThrottledJob < Mosquito::QueuedJob
  include Mosquito::RateLimiter

  params message : String
  throttle limit: 5, per: 1.minute

  def perform
    puts message
  end
end
```
