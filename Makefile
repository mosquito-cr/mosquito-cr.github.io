SHELL=/bin/bash

.PHONY: dev
dev:
	bundle exec jekyll serve --livereload
