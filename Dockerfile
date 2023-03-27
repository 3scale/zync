FROM registry.access.redhat.com/ubi8/ruby-27

USER root
RUN rpm -Uvh https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm \
  && dnf update -y \
  && dnf remove -y postgresql* \
  && dnf install --setopt=skip_missing_names_on_install=False,tsflags=nodocs -y shared-mime-info postgresql12-12.13 postgresql12-devel-12.13 postgresql12-libs-12.13 \
  && dnf clean all \
  && rm -rf /var/cache/yum

USER default
WORKDIR ${APP_ROOT}

COPY --chown=default:root Gemfile* ./

RUN BUNDLER_VERSION=$(awk '/BUNDLED WITH/ { getline; print $1 }' Gemfile.lock) \
    && gem install bundler --version=$BUNDLER_VERSION --no-document

RUN bundle config build.pg --with-pg-config=/usr/pgsql-12/bin/pg_config \
  && bundle install --deployment --path vendor/bundle --jobs $(grep -c processor /proc/cpuinfo) --retry 3

COPY --chown=default:root . .

ENV RAILS_LOG_TO_STDOUT=1

RUN bundle exec bin/rails server -e production -d; \
  rm -rf tmp/pids

RUN mkdir -p -m 0775 tmp/cache log \
  && chown -fR default tmp log db \
  && chmod -fR g+w tmp log db

CMD [".s2i/bin/run"]
