# Local integration between Porta/System with Keycloak through Zync
Install these 3 components to have a complete integration of managed SSO applications in Porta.

1. Install Porta
Follow [the installation guide](https://github.com/3scale/porta/blob/master/INSTALL.md).

2. Install Zync
Follow [the installation guide](https://github.com/3scale/zync/blob/master/INSTALL.md).

3. Install Keycloak
Run Keycloak locally.
`docker run --name keycloak -d -p 8080:8080 -e KEYCLOAK_USER=admin -e KEYCLOAK_PASSWORD=p jboss/keycloak`

Then [configure Red Hat Single Sign-On](https://access.redhat.com/documentation/en-us/red_hat_3scale_api_management/2.4/html/api_authentication/openid-connect#configure_red_hat_single_sign_on).

4. Run Zync
Go to the folder where you have zync installed and run it in the port 5000.
`ZYNC_AUTHENTICATION_TOKEN=zynctoken bundle exec rails server -p 5000`

5. Run Porta
These configurations are needed:
  - In `config/rolling_updates.yml`, make sure to have `apicast_v2: true` and `apicast_oidc: true`.
  - In `config/sandbox_proxy.yml`, make sure to have `apicast_registry_url: <%= ENV.fetch('APICAST_REGISTRY_URL', '<Insert a URL that contains policies in JSON. It can be and empty JSON>') %>`

Run porta.
`UNICORN_WORKERS=8 ZYNC_ENDPOINT=http://localhost:5000 ZYNC_AUTHENTICATION_TOKEN=zynctoken bundle exec rails server -b 0.0.0.0`

6. Run Porta's sidekiq
Run Porta's Sidekiq to process Zync Worker jobs from the `low` queue.
`ZYNC_ENDPOINT=http://localhost:5000 ZYNC_AUTHENTICATION_TOKEN=zynctoken bundle exec sidekiq -q low`

7. Configure 3scale to use Keycloak
Follow the documentation to [configure 3scale](https://access.redhat.com/documentation/en-us/red_hat_3scale_api_management/2.4/html/api_authentication/openid-connect#configure_3scale).
The url must not contain 'locahost', but it is possible to use instead `keycloak.lvh.me:8080`
Example of the whole url: `http://threescale:2b010e28-f4cf-437c-afc0-1ec0a8139196@keycloak.lvh.me:8080/auth/realms/3scale`
