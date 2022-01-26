---
layout: homepage
---

## Installation

Update your shard.yml to include mosquito, and run `shards install`:

```diff
targets:
  app:
    main: src/my_app.cr
+ worker:
+   main: src/worker.cr

dependencies:
+  mosquito:
+    github: mosquito-cr/mosquito
```

## Usage

### Step 1: Configure mosquito in your app:

```crystal
# config/worker.cr
require "mosquito"

Mosquito.configure do |settings|
  settings.redis_url = ENV["REDIS_URL"]
end
```
&nbsp;
```crystal
# src/worker.cr
require "../config/worker.cr"

Mosquito::Runner.start
```


### Step 2: Build your job:

```crystal
# src/jobs/puts_job.cr
class PutsJob < Mosquito::QueuedJob
  params message : String

  def perform
    puts message
  end
end
```

### Step 3: Queue your job:

```crystal
PutsJob.new(message: "hello world").enqueue
```

### Step 4: Run your worker to process the job

```
crystal run src/worker.cr
```

### Success!

```
> crystal run src/worker.cr
2017-11-06 17:07:29 - Mosquito is buzzing...
2017-11-06 17:07:51 - Running task puts_job<...> from puts_job
2017-11-06 17:07:51 - [PutsJob] hello world
2017-11-06 17:07:51 - task puts_job<...> succeeded, took 0.0 seconds
```
