---
layout: manual
title: Redis Storage and Queuing Model
toc: true
---

Mosquito's default backend is Redis. The redis data model leverages as much atomicity as possible from redis primitives to decrease the risk of double-run errors, lost jobs, etc.

There are two general storage mechanisms at play: hash-like metadata and queuing data.

### Hash-like Metadata

Both Jobs and Tasks are able to refer to hash-like metadata. A Task's metadata contains several fields specific to a single job run, and a Job's metadata allows storage of metadata about all job-runs for a Job.

Task metadata stores the parameter values a job run is enqueued with, and it also stores several internal metadata attributes needed for tracking and running the Job corretly:

- `id` - String, a unique identifier for this job.
- `type` - String representation of the Job class, eg `"SendWelcomeEmailJob"`
- `enqueue_time` - [`Time`](crystal-lang.org/api/latest/Time.html) representing the first time this task was enqueued.
- `retry_count` - Integer, the number of times the job has been tried and failed.

These values are stored in a [Hash](https://redis.io/docs/manual/data-types/#hashes). The Redis key for the hash is the unique task `id`.

### Queuing Data

A named Mosquito [`Queue`](https://mosquito-cr.github.io/mosquito/Mosquito/Queue.html) is represented by 4 [Sorted Sets](https://redis.io/docs/manual/data-types/#sorted-sets):

- Waiting - holds a list of jobs which need to be executed as soon as possible.
- Pending - holds a list of job runs wich are currently being executed by a runner.
- Scheduled - indexed by next execution time, and holds job runs which are planned for a later time.
- Dead - for job runs which have failed and are no longer able to be retried with the current configuration.

Each of these named sub-queues holds nothing more than a list of Task IDs.

## Queuing Model

In a typical use case a job is enqueued for immediate execution. When `ExampleJob.new(param: "value").enqueue` is called two actions take place:

  1. The Task is built, and the parameter value and task metadata is stored in a redis hash.
  1. The Task id is pushed onto the end of the `waiting` sorted set.

When a worker begins processing the job:

  1. The Task id is atomically moved from the `waiting` set to the `pending` set.
  1. The metadata and parameter hash is pulled from the hash storage.
  1. A matching Job class is initialized and the `#run` method is called.

When the worker finishes the job successfully:

  1. The Task id is removed from the `pending` set.
  1. The metadata and parameter hash is set to expire.

Slight variants exist on the queuing model for the following circumstances:

  1. The job should not be executed right away, e.g. `ExampleJob.new.enqueue in: 3.minutes`.
  1. The job is [Periodic](/manual/index.html#periodic-jobs).
  1. The job fails for some reason.

### Delayed Execution

When a job should not be attempted for some time, it is not added to the `waiting` set. Instead it is inserted to the `scheduled` sorted set. For this insertion the sort key is the desired execution time.

Periodically a runner will ask the backend for `scheduled` jobs whose scheduled time has come. Overdue task IDs are removed from the `scheduled` set and pushed onto the `waiting` set. Execution then proceeds as if the job were enqueued normally.

### Periodic Execution

When a job is to be attempted on an interval, it is not added to the `waiting` set.

Periodically a runner will check all known subclasses of `PeriodicJob` and attempt to run each. If the specific wait time has passed or the job has never been executed a task is generated and added to the `waiting` set. Execution then proceeds as if the job were enqueued normally.

### Failed Job Re-Execution

When a job is attempted and fails for some reason it is scheduled for retry at a later time, putting the task id on the `scheduled` sorted set. Each successive failure will result in a longer delay until the next execution (geometric backoff). After a configurable number of failures, the task id will be considerd unsalvageable and placed on the `dead` set with an expiration.
