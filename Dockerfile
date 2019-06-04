FROM centos/ruby-24-centos7
RUN source ${APP_ROOT}/etc/scl_enable \
 && gem install bundler --version=2.0.1 --no-document

COPY Gemfile* ./
RUN source ${APP_ROOT}/etc/scl_enable \
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
