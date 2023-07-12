FROM registry.access.redhat.com/ubi9/ruby-31

USER root
RUN dnf install --setopt=skip_missing_names_on_install=False,tsflags=nodocs -y shared-mime-info postgresql rubygem-irb rubygem-rdoc \
    && dnf clean all \
    && rm -rf /var/cache/yum

# Workaround for https://bugzilla.redhat.com/show_bug.cgi?id=2221938
RUN ln -s /usr/share/gems/gems/rdoc-6.4.0/lib/rdoc.rb /usr/share/ruby/ \
    ln -s /usr/share/gems/gems/rdoc-6.4.0/lib/rdoc /usr/share/ruby/

USER default
WORKDIR ${APP_ROOT}

COPY --chown=default:root Gemfile* ./

RUN BUNDLER_VERSION=$(awk '/BUNDLED WITH/ { getline; print $1 }' Gemfile.lock) \
    && gem install bundler --version=$BUNDLER_VERSION --no-document

RUN bundle config set --local deployment 'true' \
    && bundle config set --local path 'vendor/bundle' \
    && bundle install --jobs $(grep -c processor /proc/cpuinfo) --retry 3

COPY --chown=default:root . .

ENV RAILS_LOG_TO_STDOUT=1

RUN bundle exec bin/rails server -e production -d; \
    rm -rf tmp/pids

RUN mkdir -p -m 0775 tmp/cache log \
    && chown -fR default tmp log db \
    && chmod -fR g+w tmp log db

# Bundler runs git commands on git dependencies
# https://bundler.io/guides/git.html#local-git-repos
# git will check if the current user is the owner of the git repository folder
# This was included in git v2.35.2 or newer.
# https://github.com/git/git/commit/8959555cee7ec045958f9b6dd62e541affb7e7d9
# Openshift changes the effective UID, so this git check needs to be bypassed.
RUN git config --global --add safe.directory '*'

CMD [".s2i/bin/run"]
