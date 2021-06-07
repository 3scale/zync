# Install Zync

**Note:** you can check the [Quickstart guide](doc/Quickstart.md) for list of commands that can quickly get you going. 

## Download this repository.
```
git clone git@github.com:3scale/zync.git
```

## Install dependencies.

To run Zync you need access to a running [PostgreSQL](https://www.postgresql.org) server. You can install one with your operating system package
manager, as a container or run it remotely.

The minimum requirement for the machine running Zync is to have
 - Ruby 2.7.x
 - `psql` client tool - needed when running for `db:setup`
 - `libpq-devel` - needed to build `pg` gem during `bundle install`.

You may have to adjust `config/database.yml` or `DATABASE_URL` environment variable, see below.

## Setup Zync

There is a `setup` script to install gem dependencies,
seed the database and run Zync server.

```
./bin/setup
```

Make sure to edit configuration or set needed environment variables
beforehand. Most important environment variables you can use:

 - `ZYNC_AUTHENTICATION_TOKEN` - this one must match your running [Porta](https://github.com/3scale/porta) configuration
 - `DATABASE_URL` - depending on your PostgreSQL and `database.yml` configuration, you may want to set this one
 - `PROMETHEUS_EXPORTER_PORT` - in case you are running other 3scale components like `que` and Porta, you may need to set a different port for each of them through this variable to avoid conflict between them
 - `PORT` - change port where Zync is running (e.g. `5000`) to avoid conflict with a locally running [Porta](https://github.com/3scale/porta) server or other software, you can also use the `-p 5000` command line option

## Start Zync

When starting Zync, make sure to use a non-conflicting port on your machine
```
bundle exec rails server -p 5000
```

When starting que, make sure to set a non-conflicting Prometheus port
```
PROMETHEUS_EXPORTER_PORT=9395 bundle exec rake que
```
