#!/usr/bin/env bash

set -ev

# Config & Install
gem install bundler:$(grep -A 1 "BUNDLED WITH" Gemfile.lock | tr -d ' '| tail -n 1)
bundle install --deployment --path vendor/bundle --jobs $(grep -c processor /proc/cpuinfo) --retry 3

# Rails db:setup
bundle exec bin/rails db:wait db:setup
