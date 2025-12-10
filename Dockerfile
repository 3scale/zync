FROM registry.access.redhat.com/ubi9:9.6

ENV RUBY_MAJOR_VERSION=3 \
    RUBY_MINOR_VERSION=3 \
    APP_ROOT=/opt/app-root/src
ENV RUBY_VERSION="${RUBY_MAJOR_VERSION}.${RUBY_MINOR_VERSION}"

USER root

RUN dnf -y module enable ruby:${RUBY_VERSION} \
    && dnf install --setopt=skip_missing_names_on_install=False,tsflags=nodocs -y shared-mime-info make automake gcc gcc-c++ postgresql git ruby-devel rubygem-irb rubygem-rdoc glibc-devel libpq-devel libyaml-devel xz \
    && dnf clean all \
    && rm -rf /var/cache/yum

# Workaround for https://bugzilla.redhat.com/show_bug.cgi?id=2221938
RUN ln -s /usr/share/gems/gems/rdoc-6.4.0/lib/rdoc.rb /usr/share/ruby/ \
    ln -s /usr/share/gems/gems/rdoc-6.4.0/lib/rdoc /usr/share/ruby/

RUN mkdir -p ${APP_ROOT} \
    && chown -R 1001:root ${APP_ROOT}

# Bundler runs git commands on git dependencies
# https://bundler.io/guides/git.html#local-git-repos
# git will check if the current user is the owner of the git repository folder
# This was included in git v2.35.2 or newer.
# https://github.com/git/git/commit/8959555cee7ec045958f9b6dd62e541affb7e7d9
# Openshift changes the effective UID, so this git check needs to be bypassed.
RUN git config --global --add safe.directory '*'

USER 1001

WORKDIR ${APP_ROOT}

COPY --chown=1001:root Gemfile* ./

# Check bundler version and stop the build if it does not match the one in Gemfile.lock
RUN INSTALLED_BUNDLER=$(bundle --version | awk '{print $3}') \
    && BUNDLED_WITH=$(awk '/BUNDLED WITH/ { getline; print $1 }' Gemfile.lock) \
    && if [[ "$INSTALLED_BUNDLER" != "$BUNDLED_WITH" ]]; then \
        echo "Bundler version in Gemfile.lock is $BUNDLED_WITH, and the currently installed bundler is $INSTALLED_BUNDLER. Aborting the build." >&2 \
        && exit 1 ; \
    fi

RUN bundle config set --local deployment 'true' \
    && bundle config set --local path 'vendor/bundle' \
    && bundle install --jobs $(grep -c processor /proc/cpuinfo) --retry 3

COPY --chown=1001:root . .

ENV RAILS_LOG_TO_STDOUT=1

RUN SECRET_KEY_BASE=test bundle exec bin/rails server -e production -d; \
    rm -rf tmp/pids

RUN mkdir -p -m 0775 tmp/cache log \
    && chown -fR 1001 tmp log db \
    && chmod -fR g+w tmp log db

CMD [".s2i/bin/run"]
