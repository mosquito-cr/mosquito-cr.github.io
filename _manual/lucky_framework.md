---
layout: manual
title: Using Mosquito with Lucky
toc: true
---

Using Mosquito with Lucky is simple!

# Installation

Adding mosquito to a Lucky project requires adding a line or two each in a few files: shard.yml, shards.cr, and app.cr. It also requires adding a dedicated worker entry-point to your application: app-worker.cr.

**shard.yml**

```diff
targets:
  server:
    main: src/start_server.cr
+ worker:
+   main: src/app_worker.cr

dependencies:
  lucky:
    github: luckyframework/lucky
+  mosquito:
+    github: robacarp/mosquito
```

**src/shards.cr**

```diff
require "avram"
require "lucky"
require "carbon"
require "authentic"
+require "mosquito"
```

**src/app.cr**

```diff
require "./shards"

require "./app_database"
require "./handlers/**"
require "./models/base_model"
require "./models/mixins/**"
require "./models/**"
+require "./jobs/**"
require "../config/env"
require "../config/**"
require "../db/migrations/**"
require "./app_server"
```

**config/mosquito.cr**
```crystal
Mosquito.configure do |settings|
  settings.redis_url = (ENV["REDIS_URL"]? || "redis://localhost:6379")
end
```

**src/app_worker.cr**

```crystal
require "./app"
require "mosquito"

if LuckyEnv.development?
  Avram::Migrator::Runner.new.ensure_migrated!
  Avram::SchemaEnforcer.ensure_correct_column_mappings!
end

Mosquito::Runner.start
```

# Adding a Job

Place job definitions in src/jobs:

**src/jobs/scheduled_puts.cr**

```crystal
class SchedulerJob < Mosquito::PeriodicJob
  run_every 1.minute

  def perform
    puts "scheduled runner"
  end
end
```

# Creating/Updating records from a worker

Lucky spends a _lot_ of energy helping you avoid mistakes in the typical web-request cycle with Operations. The standard paradigm is to tie an Operation to an http-action. The _easiest_ way to save or update models from your worker is to use the bare SaveOperation associated with your model. It's also possible to create a custom SaveObject which implements validations, etc, and call that from a worker. This example job calls SaveOperation directly.

**src/jobs/send_email_job.cr**
```crystal
class SendEmailJob < Mosquito::QueuedJob
  param user_id : Int64

  def perform
    user.send_email
    log "Sent email to User##{user.id}"
    
    # Call the bare SaveOperation.update generated by an Avram table model
    User::SaveOperation.update(user, email_sent: true) do |operation, updated_user|
      if operation.saved?
        log "Updated User##{updated_user.id}"
      else
        # log the failure, providing any error messages
        log <<-LOG
          Could not update ##{user.id}
          - #{operation.errors.join("\n -")}
        LOG
      end
    end
  end

  # Provide a lookup method which hard-fails when a parameter fails
  # to match a database lookup.
  def user : User
    @_user ||= UserQuery.new.find user_id
    @_user.not_nil!
  end
end
```