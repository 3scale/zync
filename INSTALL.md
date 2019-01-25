# Install Zync

Download this repository and run `bundle install`.

Install PostgreSQL with `brew install postgresql`
Start its service with `brew services start postgresql`

Make sure that it is running. See the services running with `brew services list` and `postgresql` should be in that list with status `started` and looking green. If you see an orange `orange` started, that means that it is trying to start but it is having errors, which you can see with more detail in the logs with `tail -f /usr/local/var/log/postgres.log`.

Create the database with `rails db:create`.
