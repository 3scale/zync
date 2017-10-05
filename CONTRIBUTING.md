# Contributing

### Code style
Regarding code style like indentation and whitespace, **follow the conventions you see used in the source already.**
You can look at `.rubocop.yml` and `.codeclimate.yml`

## Modifying the code
First, ensure that you have installed Ruby 2.2+ and Postgresql

1. Fork and clone the repo.
1. Run `bundle install` to install all dependencies.

Assuming that you don't see any red, you're ready to go.

## Submitting pull requests

1. Create a new branch, please don't work in your `master` branch directly.
1. Add failing tests for the change you want to make. Run `rails test` to see the tests fail.
1. Fix stuff.
1. Run `rails test` to see if the tests pass. Repeat steps 2-4 until done.
1. Update the documentation and Changelog to reflect any changes.
1. Push to your fork and submit a pull request.
