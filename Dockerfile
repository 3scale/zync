FROM registry.access.redhat.com/ubi8/ruby-27

USER root
RUN rpm -Uvh https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm \
  && dnf install --setopt=skip_missing_names_on_install=False,tsflags=nodocs --skip-broken -y shared-mime-info postgresql13 postgresql13-libs \
  && dnf clean all \
  && rm -rf /var/cache/yum

USER default
WORKDIR ${APP_ROOT}

COPY --chown=default:root Gemfile* ./

RUN BUNDLER_VERSION=$(awk '/BUNDLED WITH/ { getline; print $1 }' Gemfile.lock) \
    && gem install bundler --version=$BUNDLER_VERSION --no-document

RUN bundle config build.pg --with-pg-config=/usr/pgsql-13/bin/pg_config \
  && bundle install --deployment --path vendor/bundle --jobs $(grep -c processor /proc/cpuinfo) --retry 3

COPY --chown=default:root . .

ENV RAILS_LOG_TO_STDOUT=1

RUN bundle exec bin/rails server -e production -d; \
  rm -rf tmp/pids

RUN mkdir -p -m 0775 tmp/cache log \
  && chown -fR default tmp log db \
  && chmod -fR g+w tmp log db

CMD [".s2i/bin/run"]
