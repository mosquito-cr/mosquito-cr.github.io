---
layout: manual
title: Before/After Hooks
---

All Jobs have a built in interface for executing code before and after a
`#perform` method. This is a general purpose strategy for tasks like
preemption, monitoring, rate limiting, failure notifications, etc.


# Before Hooks

A before hook is one strategy to rate limit jobs which might have negative consequences for running too frequently.

When a Job run needs to be delayed consider using [#retry_later](https://mosquito-cr.github.io/mosquito/Mosquito/Job.html#retry_later-instance-method) or [#fail](https://mosquito-cr.github.io/mosquito/Mosquito/Job.html#fail%28reason%3D%22%22%29-instance-method).

```crystal
class NotifyUserJob < Mosquito::QueuedJob
  param user_id : Int32

  before do
    # prevent spamming a user with notifications
    fail if (Time.utc - user.last_notification_sent) < 2.minutes
  end

  def perform
    user.last_notification_sent = Time.utc
    user.notify!
  end

  def user : User
    found_user = UserService.fetch user_id
    fail unless found_user
    found_user
  end
end
```

The mosquito built in [Rate Limiting module]({% link _manual/rate_limiting.md %}) makes use of a before hook to halt and reschedule a job run.

# After Hooks

An after hook doesn't have the ability to prevent a job from running. It gets run regardless of job success, even if a job throws an exception, or is never run due to a before hook.

```crystal
class MonitoredJob < Mosquito::QueuedJob
  def perform
    System.long_running_failure_prone_task
  end

  after do
    System.send_admin_email("the long running task failed again") unless succeeded?
  end
end
```

If a job fails implicitly by throwing an exception it is stored in the `#exception` variable and can be inspected in an after hook:

```crystal
class FailingJob < Mosquito::QueuedJob
  def perform
    raise IndexError.new("Index out of bounds")
  end

  after do
    if failed && thrown_exception = exception
      System.send_admin_email("Job failed with an exception. #{thrown_exception.message}")
    end
  end
end
```
