# Install Zync

## Download this repository.
`git clone git@github.com:3scale/zync.git`

## Setup PostgreSQL on Mac

There is `Brewfile` containing all the dependencies.

```
cd zync
brew bundle
brew services start postgresql
```

The command `brew services start postgresql` starts the service of PostgreSQL. If later `./bin/setup` aborts, make sure that the `PostgreSQL` service is running. Verify with `brew services list` that has a status `started` and looking green. If the status is `started` but coloured orange, fix the errors indicated in the log located in `/usr/local/var/log/postgres.log`

## Setup PostgreSQL on Fedora 34

```shell
sudo dnf module install postgresql:10
sudo dnf install libpq-devel
sudo /usr/bin/postgresql-setup --initdb
systemctl enable postgresql
systemctl start postgresql
psql -U postgres -c "create user ${USER}"
psql -U postgres -c "create database zync_development with owner ${USER}"
psql -U postgres -c "create database zync_test with owner ${USER}"
psql -U postgres -c "create database zync_production with owner ${USER}"
```

## Setup PostgreSQL as a container with Docker or Podman

```
docker run -d -p 5432:5432 -e POSTGRES_USER=postgres -e POSTGRES_DB=zync --name postgres10-zync docker.io/circleci/postgres:10.5-alpine
```

When running any Zync command, make sure to have `DATABASE_URL` environment variable set in prior.

```
export DATABASE_URL=postgresql://postgres:@localhost:5432/zync
```

**Note:** You will also have to install on the host machine `psql` client tool (needed for `db:setup`) and `libpq-devel` (needed to build `pg` gem).

## Setup Zync
`./bin/setup`


## Start Zync
```
export ZYNC_AUTHENTICATION_TOKEN=token # must match porta config
bundle exec rails server -p 5000
PROMETHEUS_EXPORTER_PORT=9395 bundle exec rake que
```
