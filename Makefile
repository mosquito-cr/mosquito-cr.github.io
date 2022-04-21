SHELL=/bin/bash

.PHONY: dev
dev:
	bundle exec jekyll serve & yarn run browser-sync --config=bs-config.json start
