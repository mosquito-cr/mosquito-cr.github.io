---
layout: manual
title: Error Handling for Jobs
toc: false
---

Mosquito runners can easily be hooked up to Honeybadger, Sentry, etc. Here is a reference implementation which will capture and dispatch errors to an aggregation service.

```crystal
module ErrorHandler
  macro included
    after do
      return unless failed?
      # Dispatch the exception to Honeybadger - https://github.com/honeybadger-io/honeybadger-crystal/
      # Honeybadger.dispatch exception

      # Capture the exception in Sentry with Raven - https://github.com/sija/raven.cr
      # Raven.capture exception
    end
  end
end
```

That module can be included into one or all jobs:

```crystal
class ExampleJob < Mosquito::QueuedJob
  include ErrorHandler

  def perform
    # da da da
    # lie lie lie

    # Fails the job and will send the exception as configured.
    raise "Error! Couldn't fluxate the encabulator!"
  end
end
```
