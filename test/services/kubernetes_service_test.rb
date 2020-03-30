# frozen_string_literal: true

require 'test_helper'
require 'base64'

class Integration::KubernetesServiceTest < ActiveSupport::TestCase
  include Base64

  def before_setup
    @_env = ENV.to_hash
    super
  end

  def after_teardown
    ENV.replace(@_env)
    super
  end

  test 'create ingress ' do
    ENV['KUBERNETES_NAMESPACE'] = 'zync'
    ENV['KUBE_TOKEN'] = strict_encode64('token')
    ENV['KUBE_SERVER'] = 'http://localhost'
    ENV['KUBE_CA'] = encode64 <<~CERTIFICATE
      -----BEGIN CERTIFICATE-----
      MIIBZjCCAQ2gAwIBAgIQBHMSmrmlj2QTqgFRa+HP3DAKBggqhkjOPQQDAjASMRAw
      DgYDVQQDEwdyb290LWNhMB4XDTE5MDQwNDExMzI1OVoXDTI5MDQwMTExMzI1OVow
      EjEQMA4GA1UEAxMHcm9vdC1jYTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABGG2
      NDgiBuXNVWVVxrDNVjPsKm14wg76w4830Zn3K24u03LJthzsB3RPJN9l+kM7ryjg
      dCenDYANVabMMQEy2iGjRTBDMA4GA1UdDwEB/wQEAwIBBjASBgNVHRMBAf8ECDAG
      AQH/AgEBMB0GA1UdDgQWBBRfJt1t0sAlUMBwfeTWVv2v4XNcNjAKBggqhkjOPQQD
      AgNHADBEAiB+MlaTocrG33AiOE8TrH4N2gVrDBo2fAyJ1qDmjxhWvAIgPOoAoWQ9
      qwUVj52L6/Ptj0Tn4Mt6u+bdVr6jEXkZ8f0=
      -----END CERTIFICATE-----
    CERTIFICATE

    service = Integration::KubernetesService.new(nil)

    proxy = entries(:proxy)

    stub_request(:get, 'http://localhost/apis/route.openshift.io/v1').
      with(
        headers: {
          'Accept'=>'application/json',
          'Authorization'=>'Bearer token',
        }).
      to_return(status: 200, body: {
        kind: "APIResourceList",
        apiVersion: "v1",
        groupVersion: "route.openshift.io/v1",
        resources: [
          { name: "routes", singularName: "", namespaced: true, kind: "Route", verbs: %w(create delete deletecollection get list patch update watch), categories: ["all"] },
        ]
      }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, 'http://localhost/apis/route.openshift.io/v1/namespaces/zync/routes?labelSelector=3scale.net/created-by=zync,3scale.net/tenant_id=298486374,zync.3scale.net/record=Z2lkOi8venluYy9Qcm94eS8yOTg0ODYzNzQ,zync.3scale.net/ingress=proxy,3scale.net/service_id=2').
      with(
        headers: {
          'Accept'=>'application/json',
          'Authorization'=>'Bearer token',
        }).
      to_return(status: 200, body: {
        kind: 'RouteList',
        apiVersion: 'route.openshift.io/v1',
        metadata: { selfLink: '/apis/route.openshift.io/v1/namespaces/zync/routes', resourceVersion: '651341' },
        items: [] }.to_json, headers: { 'Content-Type' => 'application/json' })

    service.call(proxy)
  end

  class RouteSpec < ActiveSupport::TestCase
    test 'secure routes' do
      url = 'https://my-api.example.com'
      service_name = 'My API'
      port = 7443
      spec = Integration::KubernetesService::RouteSpec.new(url, service_name, port)
      json = {
        host: "my-api.example.com",
        port: {targetPort: 7443},
        to: {kind: "Service", name: "My API"},
        tls: {insecureEdgeTerminationPolicy: "Redirect", termination: "edge"}
      }
      assert_equal json, spec.to_hash


      url = 'http://my-api.example.com'
      service_name = 'My API'
      port = 7780
      spec = Integration::KubernetesService::RouteSpec.new(url, service_name, port)
      json = {
        host: "my-api.example.com",
        port: {targetPort: 7780},
        to: {kind: "Service", name: "My API"},
        tls: nil
      }
      assert_equal json, spec.to_hash
    end
  end
end
