## Overview

A quick way to get Zync running locally without many details.
Check [README](../README.md) and [INSTALL](../INSTALL.md) for
more details.

## Download this repository.
```
git clone git@github.com:3scale/zync.git
```

## Run PostgreSQL on Mac

```
cd zync
brew bundle
brew services start postgresql
```

**Note:** The command `brew services start postgresql` starts the service of PostgreSQL. If later `./bin/setup` aborts, make sure that the `PostgreSQL` service is running. Verify with `brew services list` that has a status `started` and looking green. If the status is `started` but coloured orange, fix the errors indicated in the log located in `/usr/local/var/log/postgres.log`

## Run PostgreSQL on Fedora 34

```shell
sudo dnf module install postgresql:10
sudo dnf install libpq-devel
sudo /usr/bin/postgresql-setup --initdb
sudo systemctl enable postgresql
sudo systemctl start postgresql
sudo -i -u postgres createuser $USER
sudo -i -u postgres createdb -O $USER zync_development
sudo -i -u postgres createdb -O $USER zync_test
sudo -i -u postgres createdb -O $USER zync_production
```

## Run PostgreSQL as a container with Docker or Podman

```
docker run -d -p 5432:5432 -e POSTGRES_USER=postgres -e POSTGRES_DB=zync --name postgres10-zync docker.io/circleci/postgres:10.5-alpine
```

**Note:** With such a setup make sure to have `DATABASE_URL` environment variable set
prior starting Zync. You will also have to install on the host machine `psql` client
tool (needed for `db:setup`) and `libpq-devel` (needed to build `pg` gem).

```
export DATABASE_URL=postgresql://postgres:@localhost:5432/zync
```

## Start Zync

```
export ZYNC_AUTHENTICATION_TOKEN=token # must match porta config
./bin/setup
PROMETHEUS_EXPORTER_PORT=9395 bundle exec rake que
```
