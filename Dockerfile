FROM registry.access.redhat.com/ubi7/ruby-25

USER root
RUN rpm -Uvh http://yum.postgresql.org/9.6/redhat/rhel-7-x86_64/pgdg-centos96-9.6-3.noarch.rpm \
  && yum update -y \
  && yum remove -y postgresql \
  && yum install -y postgresql96 postgresql96-devel postgresql96-libs \
  && yum clean all \
  && rm -rf /var/cache/yum

RUN source ${APP_ROOT}/etc/scl_enable \
 && gem install bundler --version=2.0.1 --no-document

COPY Gemfile* ./
RUN source ${APP_ROOT}/etc/scl_enable \
  && bundle config build.pg --with-pg-config=/usr/pgsql-9.6/bin/pg_config \
  && bundle install --deployment --path vendor/bundle --jobs $(grep -c processor /proc/cpuinfo) --retry 3
COPY . .
ENV RAILS_LOG_TO_STDOUT=1
USER root
RUN mkdir -p tmp log; chmod -vfR g+w tmp log
USER default
RUN source ${APP_ROOT}/etc/scl_enable \
&& bundle exec bin/rails server -e production -d; \
rm -rf tmp/pids
USER root
RUN chmod -fR g+w tmp/cache
USER default

CMD [".s2i/bin/run"]
