---
layout: manual
title: Versioning
toc: true
---

## SemVer

Mosquito strictly follows [SemVer](https://semver.org/) versioning. This means that you can trust the API is stable within a major version. Any API drift within a major version is unintentional and can be considered a bug.

## Release Candidates

A release candidate will be tagged following the form `v1.0.0rc1` where the version that will be released is `1.0.0` and the candidate revision is `1`.

Release candidates can be installed with this modified shard.yml stanza:

```diff
dependencies:
+  mosquito:
+    github: mosquito-cr/mosquito
+    version: "1.0.0.rc1" # no leading v
```
