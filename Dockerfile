FROM registry.access.redhat.com/ubi7/ruby-25

USER root

  && yum update -y \
  && yum remove -y postgresql \
  && yum install -y postgresql96 postgresql96-devel postgresql96-libs \
  && yum clean all \
  && rm -rf /var/cache/yum

USER default
WORKDIR ${APP_ROOT}

RUN source ${APP_ROOT}/etc/scl_enable \
  && gem install bundler --version=2.0.1 --no-document

COPY --chown=default:root Gemfile* ./
RUN source ${APP_ROOT}/etc/scl_enable \
  && bundle config build.pg --with-pg-config=/usr/pgsql-9.6/bin/pg_config \
  && bundle install --deployment --path vendor/bundle --jobs $(grep -c processor /proc/cpuinfo) --retry 3

COPY --chown=default:root . .

ENV RAILS_LOG_TO_STDOUT=1
RUN source ${APP_ROOT}/etc/scl_enable \
  && bundle exec bin/rails server -e production -d; \
  rm -rf tmp/pids

RUN mkdir -p -m 0775 tmp/cache log \
  && chown -fR default tmp log db \
  && chmod -fR g+w tmp log db

CMD [".s2i/bin/run"]
