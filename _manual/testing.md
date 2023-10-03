---
layout: manual
title: Testing
---

Mosquito provides a testing backend which keeps track of jobs which have been enqueued.

To activate the testing backend add this configuration to `test_helper.cr` or the equivalent in your project.

```crystal
Mosquito.configure do |settings|
  settings.backend = Mosquito::TestBackend
end
```

Then in your tests:

```crystal
describe "testing" do
  it "enqueues the job" do
    # build and enqueue a job
    job_run = EchoJob.new(text: "hello world").enqueue

    # assert that the job was enqueued
    lastest_enqueued_job = Mosquito::TestBackend.enqueued_jobs.last

    # check the job config
    assert_equal "hello world", latest_enqueued_job.config["text"]

    # check the job_id matches
    assert_equal job_run.id, latest_enqueued_job.id

    # optionally, truncate the history
    Mosquito::TestBackend.flush_enqueued_jobs!
  end
end
```
