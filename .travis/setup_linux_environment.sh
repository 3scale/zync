#!/bin/bash

set -ev

# Config & Install
gem install bundler --version=2.0.1
bundle install --deployment --path vendor/bundle --jobs $(grep -c processor /proc/cpuinfo) --retry 3

# Rails db:setup
bundle exec bin/rails db:wait db:setup
