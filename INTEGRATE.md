# Local integration between Porta/System with Keycloak through Zync

## Install Porta
Follow [the installation guide](https://github.com/3scale/porta/blob/master/INSTALL.md).

## Install Zync
Follow [the installation guide](https://github.com/3scale/zync/blob/master/INSTALL.md).

## Install Keycloak
You can have a keycloak running locally with `docker run --name keycloak -d -p 8080:8080 -e KEYCLOAK_USER=admin -e KEYCLOAK_PASSWORD=p jboss/keycloak`
So that docker container with keycloak will be accessible from your browser in `http://localhost:8080`.

After that, you will need to follow the instructions to [configure Red Hat Single Sign-On](https://access.redhat.com/documentation/en-us/red_hat_3scale_api_management/2.4/html/api_authentication/openid-connect).

## Run Zync
From the folder where you have Zync installed, run: `ZYNC_AUTHENTICATION_TOKEN=zynctoken bundle exec rails server -p 5000` so you will get zync running in the port 5000.

## Run Porta
If your porta is already running, stop it, and if you have `spring`, also do `spring stop`.
You will need these configurations:
  - In `config/rolling_updates.yml`, make sure you have `apicast_v2: true` and `apicast_oidc: true`.
  - In `config/sandbox_proxy.yml`, make sure you have `apicast_registry_url: <%= ENV.fetch('APICAST_REGISTRY_URL', '<Insert a URL that contains policies in JSON. It can be am empty JSON>') %>`

Run porta with `UNICORN_WORKERS=8 ZYNC_ENDPOINT=http://localhost:5000 ZYNC_AUTHENTICATION_TOKEN=zynctoken bundle exec rails server -b 0.0.0.0`

### Run Porta's sidekiq
It works in Background in the `low` queue so do this: `ZYNC_ENDPOINT=http://localhost:5000 ZYNC_AUTHENTICATION_TOKEN=zynctoken bundle exec sidekiq -q default -q mailers -q low -q critical`

## Configure 3scale to use Keycloak
Follow the documentation to [configure 3scale](https://access.redhat.com/documentation/en-us/red_hat_3scale_api_management/2.4/html/api_authentication/openid-connect).
The url must not contain 'locahost', so you can use instead `keycloak.lvh.me:8080`
Example of the whole url: `http://threescale:2b010e28-f4cf-437c-afc0-1ec0a8139196@keycloak.lvh.me:8080/auth/realms/3scale`
