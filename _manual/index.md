---
layout: manual
toc: true
title: Mosquito Manual
---

# Terminology

**Job** - a collection of code which can be run several times, either on
demand, scheduled for a specific time, or periodically.

**Task** - A specific unit of work to be performed by a job.

**PeriodicJob** - A job which is automatically scheduled to run once every
interval.

**QueuedJob** - A job which is scheduled to run at a specific time, or as soon
as possible.

# Usage

## Installation

Update your `shard.yml` to include mosquito:

```diff
dependencies:
+  mosquito:
+    github: mosquito-cr/mosquito
```
&nbsp;
```crystal
# require your application here
require "./my_application/*.cr"

Mosquito.configure do |settings|
  settings.redis_url = "redis://path-to-your-redis:6379"
end

Mosquito::Runner.start
```

Your worker can then be run using `crystal run src/worker.cr`.

## Configuration

For a fine grained control of the way Mosquito runs jobs extra parameters may
be passed in the `Mosquito.configure` block. The default values for these
settings should suffice most runner configurations.

- `redis_url : String` - a redis connection string, eg
  `rediss://password@host/database_number`.
- `idle_wait : Float | Time::Span = 0.1` (Seconds, default: 0.1s) - the time
  Mosquito `sleep`s between checking for pending jobs.
- `successful_job_ttl : Int = 1` (Seconds, default: 1s) - how long a job config
  is persisted in Redis after a task succeeds.
- `failed_job_ttl : Int = 86400` (Seconds, default: 1 day) - how long a job
  config is persisted in Redis after a task fails.
- `run_cron_scheduler : Bool = true` - toggle the cron scheduler on or off.
- `run_from : Array(String) = []` - a list of queue names to pull jobs from.

Example:

```crystal
Mosquito.configure do |settings|
  settings.idle_wait = 3.seconds
  settings.successful_job_ttl = 300 # 5 minutes
  settings.failed_job_ttl = 86400 # 1 day
end
```

## Declaring a job

```crystal
# src/jobs/puts_job.cr
class PutsJob < Mosquito::QueuedJob
  params message : String

  def perform
    puts message
  end
end
```

## Queuing a job

Queued Jobs are enqueued with the
[`#enqueue`](https://mosquito-cr.github.io/mosquito/Mosquito/QueuedJob.html#enqueue%28indelay_interval%3ATime%3A%3ASpan%29%3ATask-instance-method)
method:


```crystal
PutsJob.new(message: "Hello from the other side").enqueue
```

# Periodic Jobs

_AKA CRON jobs_

Periodic jobs run according to a predefined period rather than manually
enqueued. They take no parameters and, since the job will be re-executed on
schedule anyway, periodic jobs are not automatically re-attempted upon failure.

## Example

This is a periodic job:

```crystal
class PeriodicallyPutsJob < Mosquito::PeriodicJob
  run_every 1.minute

  def perform
    emotions = %w{happy sad angry optimistic political skeptical epuhoric}
    log "The time is now #{Time.now} and the wizard is feeling #{emotions.sample}"
  end
end
```
And this is the output from running Mosquito with PeriodicallyPutsJob active:
```
2017-11-06 17:20:13 - Mosquito is buzzing...
2017-11-06 17:20:13 - Queues: periodically_puts_job
2017-11-06 17:20:13 - Running task periodically_puts_job<...> from periodically_puts_job
2017-11-06 17:20:13 - [PeriodicallyPutsJob] The time is now 2017-11-06 17:20:13 and the wizard is feeling skeptical
2017-11-06 17:20:13 - task periodically_puts_job<...> succeeded, took 0.0 seconds
2017-11-06 17:21:14 - Queues: periodically_puts_job
2017-11-06 17:21:14 - Running task periodically_puts_job<...> from periodically_puts_job
2017-11-06 17:21:14 - [PeriodicallyPutsJob] The time is now 2017-11-06 17:21:14 and the wizard is feeling optimistic
2017-11-06 17:21:14 - task periodically_puts_job<...> succeeded, took 0.0 seconds
2017-11-06 17:22:15 - Queues: periodically_puts_job
2017-11-06 17:22:15 - Running task periodically_puts_job<...> from periodically_puts_job
2017-11-06 17:22:15 - [PeriodicallyPutsJob] The time is now 2017-11-06 17:22:15 and the wizard is feeling political
2017-11-06 17:22:15 - task periodically_puts_job<...> succeeded, took 0.0 seconds
```

## Periodic Job Design

Periodic jobs should be minimal and fast, but more important, they should be:

1. [Idempotent](https://en.wikipedia.org/wiki/Idempotence) - should be
   resilient enough to be run at _any_ frequency, regardless of the requested
   interval.
1. Immune to failure - no condition should exist in the job which leads to a
   broken _application_ state.
1. Self sufficient - any input required to complete the task must be acquired
   as part of the task run.

## Execution Frequency

Jobs are declared so that they are run _at least_ every interval. No guarantee
is provided they will not run more frequently. Specifically, a worker restart
will execute every periodic job once.

Specify the execution frequency with the `run_every` macro: `run_every
1.minute`. Any `Time::Span` or `Time::MonthSpan` is a valid frequency.

## Execution Environment

Periodic jobs are similar to CRON. The periodic scheduler has no application
context and cannot initialize scheduled jobs with any knowledge about the
application state. As a result no inputs are available to periodic jobs. Any
input required must be fetched during the #perform method.

## Retries

Upon failure, a periodic job is not retried. A periodic job is expected to run
again later on the pre-existing schedule.

# Queued Jobs

_AKA Background jobs_

Mosquito Queued jobs are executed on demand.

## Example

This is a queued job:

```crystal
class LongRunningTaskJob < Mosquito::QueuedJob
  params user_id : Int32

  def perform
    AssetCompressor.new(for: user).compress
  end

  def user : User
    found_user = UserService.fetch user_id
    fail unless found_user
    found_user
  end
end
```

## Job Design

Queued jobs needn't be fast or immune to failure, but they should be tolerant
of retries. By default a failed job is retried up to 4 times on a predictable
schedule before mosquito gives up.

It is best to keep your application logic in your application and simply use a
background job to trigger that logic. Instead of:

```crystal
def perform
  # send welcome email
  sign_up_email = UserEmailer.sign_up_email.render user
  EmailVendor.send email: sign_up_email

  # notify admins of a new user
  admin_notification = AdminEmailer.user_signed_up.render user
  EmailVendor.send email: admin_notification
end
```

Consider putting the "stuff that happens when a user signs up" in an Operation
or other service object:

```crystal
def perform
  SignUpOperation.perform user
end
```

## Execution

Queued jobs are manually enqueued and then expected to be executed _later_ but
with no specification about how soon that execution will take place.

In order to execute a job, simply ask it to be enqueued:

```crystal
new_user = User.create email: "someone@somewhere.com"
SendWelcomeEmailJob.new(user: new_user).enqueue
```

## Failure

Any exceptions thrown during the course of a #perform are logged and the job is
scheduled for a retry.

A job can also be failed manually with the
[`Job#fail`](https://mosquito-cr.github.io/mosquito/Mosquito/Job.html#fail-instance-method)
method:

```crystal
class SendWelcomeEmailJob < Mosquito::QueuedJob
  params user : User

  def perform
    if user.ready_to_welcome?
      user.send_welcome
    else
      fail
    end
  end
end
```

Retries can also be prevented if desired, See
[`Job#rescheduleable?`](https://mosquito-cr.github.io/mosquito/Mosquito/Job.html#rescheduleable%3F%3ABool-instance-method)

The retry schedule defaults to a geometric back-off. It can be overridden by
reimplementing the
[`Job#reschedule_interval`](https://mosquito-cr.github.io/mosquito/Mosquito/Job.html#reschedule_interval%28retry_count%3AInt32%29%3ATime%3A%3ASpan-instance-method)
method on a Job.

## Logs

Each job provides a `log` method which can be used to emit information which
should be logged as part of a task. Usage is similar to `puts`. Mosquito
prefixes log messages with the job name:

```crystal
class LogJob < Mosquito::QueuedJob
  def perform
    log "ohai background job"
  end
end
```
&nbsp;
```diff
2017-11-06 17:07:29 - Mosquito is buzzing...
2017-11-06 17:07:51 - Running task log_job<...> from log_job
+2017-11-06 17:07:51 - [LogJob] ohai background job
2017-11-06 17:07:51 - task log_job<...> succeeded, took 0.0 seconds
```

# Parameters

Job parameters can be declared with the `params` macro. Parameters are
serialized, stored in Redis, and [deserialized](#primitive-serialization) before the
[`Job#perform`](https://mosquito-cr.github.io/mosquito/Mosquito/Job.html#perform-instance-method)
method is called. A typed constructor is also declared so that enqueuing jobs
is defended by type safe code.

```crystal
class SendEmailJob < Mosquito::QueuedJob
  # Declaring parameters also declares a typed constructor and getter methods
  params(email_address : String)

  # These will be generated:
  # def email_address : String?; ... end
  # def email_address! : String; ... end
  # def initialize(@email_address : String); ... end
end
```

## Default Values

Optionally a job parameter can have a default value. The generated constructor
will take that value as a default as well. Take care to follow the usual
semantics for default value parameters on a method. Required parameters should
be first, followed by optional parameters.

```crystal
class SendEmailJob < Mosquito::QueuedJob
  params(to : String, from : String = "no-reply@mosquito")

  # generated code:
  # def initialize(@to : String, @from : String = "no-reply@mosquito"); ... end
end
```

Parameter values are stored in instance variables of the same name, as with the
[Object#parameter](https://crystal-lang.org/api/0.35.1/Object.html#property(*names,&block)-macro)
macro.

## Caveats

Be careful when adding parameters to a Job definition when jobs are already
running in production. Tasks which are stored for later execution in redis will
fail because the parameters don't all exist in the serialized task. Consider
this example:

- `RemindUserAboutAbandonedCartJob` with params: email_address, last_active_date
- A user joins, and the task is enqueued
- new code is deployed, `RemindUserAboutAbandonedCartJob` now has params:
  email_address, last_active_date, join_date
- when the task is popped off the queue, it doesn't contain a serialized join_date

# Scheduling Jobs

Delayed job systems often provide the ability to run a job at a specific time.
Mosquito provides to overloads to `#enqueue` which allow job scheduling.

For example:

```crystal
# Enqueue a job after a Time::Span
PutsJob.new(message: "ohai background job").enqueue(in: 30.seconds)
```

```crystal
# Enqueue a job at a specific Time
PutsJob.new(message: "ohai background job").enqueue(at: Time.utc(2022, 1, 1, 0, 0,0))
```

This delayed execution logic is used to implement the [geometric back-off
retry](/mosquito-cr/mosquito/wiki/Job-Failures-and-Retries) flow.

## Caveats

Mosquito is not a precise scheduler. The Mosquito Runner checks to see what
tasks are overdue at _most_ once every second but there is no guarantee that it
will happen at _least_ every second. If the worker is bogged down with jobs it
is possible that a job will not be processed at the specified time. 

Scheduled jobs are enqueued with equal priority to other "on demand" jobs at
the scheduled time. They have equal priority to the worker as other jobs,
including jobs which have failed and will be retried.

In mosquito, jobs which fail are automatically scheduled for a retry later. The
default retry algorithm is:

- Retry at most 4 times
- Delay 2^n seconds between retries, where n is the number of failed executions

Assuming a job that always fails, the retry algorithm produces roughly this
timeline:

```text
mm:ss
00:00 - job run #1
00:02 - job run #2
00:10 - job run #3
00:28 - job run #4
00:50 - job run #5 (no further retry)
```

As tasks created by this job run, the log output will look something like this:

```text
Running task background_job<...> from background_job
Failure: task background_job<...> failed, taking no discernible time at all and will run again in 00:00:02
Found 1 delayed tasks
Running task background_job<...> from background_job
Failure: task background_job<...> failed, taking no discernible time at all and will run again in 00:00:08
Found 1 delayed tasks
Running task background_job<...> from background_job
Failure: task background_job<...> failed, taking 9.0ms and will run again in 00:00:18
Found 1 delayed tasks
Running task background_job<...> from background_job
Failure: task background_job<...> failed, taking no discernible time at all and will run again in 00:00:32
Found 1 delayed tasks
Running task monitor_job<...> from monitor_job
Failure: task monitor_job<...> failed, taking no discernible time at all and cannot be rescheduled
```

## Per-job retry configuration

Job definitions can be configured to _never_ retry failed tasks by adding this
method to the job definition:

```crystal
def rescheduleable?
  false
end
```

Granular configuration of the retry schedule is not available on a per-job basis.

## Periodic jobs and retries

By default periodic jobs are not retried. Overriding this behavior is not
recommended. Jobs which perform according to a schedule should be idempotent,
fail-safe, and simple.

# Primitive Serialization

Redis and Mosquito can only store task parameters in string form, but Mosquito
knows how to serialize and de-serialize many of the Crystal primitives:

- String
- Bool
- Char
- UUID
- Int (8,16,32,64,128)
- Uint (8,16,32,64,128)
- Float (32,64)
