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

  setup do
    Integration::KubernetesService.use_openshift_route = nil
    Rails.application.config.integrations[:kubernetes_force_native_ingress] = false

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

    stub_request(:get, 'http://localhost/apis').
      with(
        headers: {
          'Accept'=>'application/json',
          'Authorization'=>'Bearer token',
        }).
      to_return(status: 200, body: {
        kind: "APIGroupList",
        apiVersion: "v1",
        groups: [
          { name: "networking.k8s.io", versions: [{ groupVersion: "networking.k8s.io/v1", version: "v1" }], preferredVersion: { groupVersion: "networking.k8s.io/v1", version: "v1" } },
          { name: "route.openshift.io", versions: [{ groupVersion: "route.openshift.io/v1", version: "v1" }], preferredVersion: { groupVersion: "route.openshift.io/v1", version: "v1" } },
        ]
      }.to_json, headers: { 'Content-Type' => 'application/json' })

    @service = Integration::KubernetesService.new(nil).freeze
  end

  attr_reader :service

  test 'create openshift route' do
    proxy = entries(:proxy)

    stub_request(:get, 'http://localhost/apis/route.openshift.io/v1').
      with(headers: request_headers).
      to_return(status: 200, body: {
        kind: 'APIResourceList',
        apiVersion: 'v1',
        groupVersion: 'route.openshift.io/v1',
        resources: [
          { name: 'routes', singularName: '', namespaced: true, kind: 'Route', verbs: %w(create delete deletecollection get list patch update watch), categories: ['all'] },
        ]
      }.to_json, headers: response_headers)

    stub_request(:get, 'http://localhost/apis/route.openshift.io/v1/namespaces/zync/routes?labelSelector=3scale.net/created-by=zync,3scale.net/tenant_id=298486374,zync.3scale.net/record=Z2lkOi8venluYy9Qcm94eS8yOTg0ODYzNzQ,zync.3scale.net/ingress=proxy,3scale.net/service_id=2').
      with(headers: request_headers).
      to_return(status: 200, body: {
        kind: 'RouteList',
        apiVersion: 'route.openshift.io/v1',
        metadata: { selfLink: '/apis/route.openshift.io/v1/namespaces/zync/routes', resourceVersion: '651341' },
        items: []
      }.to_json, headers: response_headers)

    service.call(proxy)
  end

  test 'route status missing ingress' do
    # stub api resource list requests (kinds 'pods' and 'routes')
    stub_request(:get, 'http://localhost/api/v1').
      with(headers: request_headers).
      to_return(status: 200, body: {
        kind: 'APIResourceList',
        apiVersion: 'v1',
        groupVersion: 'apps.3scale.net/v1alpha1',
        resources: [
          { name: 'pods', singularName: '', namespaced: true, kind: 'pod', verbs: %w(create delete deletecollection get list patch update watch), categories: ['all'] },
        ]
      }.to_json, headers: response_headers)

    stub_request(:get, 'http://localhost/apis/route.openshift.io/v1').
      with(headers: request_headers).
      to_return(status: 200, body: {
        kind: 'APIResourceList',
        apiVersion: 'v1',
        groupVersion: 'route.openshift.io/v1',
        resources: [
          { name: 'routes', singularName: '', namespaced: true, kind: 'Route', verbs: %w(create delete deletecollection get list patch update watch), categories: ['all'] },
        ]
      }.to_json, headers: response_headers)

    # stub route owner
    ENV['POD_NAME'] = 'zync-que-123'
    route_owner = { kind: 'Pod', apiVersion: 'v1', metadata: { name: 'zync-que-123', generateName: 'zync-que-', namespace: 'zync', selfLink: '/api/v1/namespaces/zync/pods/zync-que-123', uid: 'b145c845-7222-44ce-8d9d-f13b8f357de6', resourceVersion: '3620670' } }

    stub_request(:get, "http://localhost/api/v1/namespaces/zync/pods/#{route_owner.dig(:metadata, :name)}").
      with(headers: request_headers).
      to_return(status: 200, body: route_owner.to_json, headers: response_headers)

    route_owner_reference = route_owner.slice(:kind, :apiVersion).merge(**route_owner[:metadata].slice(:name, :uid), controller: nil, blockOwnerDeletion: nil)

    # base objects for creating provider routes
    entry = entries(:provider)
    provider_id = entry.data.fetch('id')
    provider = entry.model.record
    tenant_id = entry.tenant_id
    record_gid = provider.to_gid_param

    provider_route_labels = {
      '3scale.net/created-by' => 'zync',
      '3scale.net/tenant_id' => tenant_id.to_s,
      'zync.3scale.net/record' => record_gid,
      'zync.3scale.net/ingress' => 'provider',
      '3scale.net/provider_id' => provider_id.to_s
    }

    provider_route_annotations = {
      '3scale.net/gid' => entry.to_gid.to_s,
      'zync.3scale.net/gid' => provider.to_gid.to_s
    }

    route_list = {
      kind: 'RouteList',
      apiVersion: 'route.openshift.io/v1',
      metadata: { selfLink: '/apis/route.openshift.io/v1/namespaces/zync/routes', resourceVersion: '651341' },
      items: []
    }

    # stub for creating provider route to system-developer
    system_developer_route_labels = provider_route_labels.merge('zync.3scale.net/route-to' => 'system-developer')
    system_developer_route_annotations = provider_route_annotations.merge('zync.3scale.net/host' => 'provider.example.com')
    system_developer_route = {
      kind: 'Route',
      apiVersion: 'route.openshift.io/v1',
      metadata: {
        namespace: 'zync',
        name: 'zync-3scale-provider-grvkd',
        uid: '3882e5dc-1f8f-460e-a1cc-ee4c5f35a709',
        selfLink: '/apis/route.openshift.io/v1/namespaces/zync/routes/zync-3scale-provider-grvkd',
        labels: system_developer_route_labels,
        annotations: system_developer_route_annotations
      },
      status: {}
    }

    stub_request(:get, "http://localhost/apis/route.openshift.io/v1/namespaces/zync/routes?labelSelector=3scale.net/created-by=zync,3scale.net/tenant_id=#{tenant_id},zync.3scale.net/record=#{record_gid},zync.3scale.net/route-to=system-developer").
      with(headers: request_headers).
      to_return(status: 200, body: route_list.to_json, headers: response_headers)

    stub_request(:post, 'http://localhost/apis/route.openshift.io/v1/namespaces/zync/routes').
      with(headers: request_headers, body: {
        metadata: {
          generateName: 'zync-3scale-provider-',
          namespace: 'zync',
          labels: system_developer_route_labels,
          ownerReferences: [route_owner_reference],
          annotations: system_developer_route_annotations
        },
        spec: {
          host: 'provider.example.com',
          port: { targetPort: 'http' },
          to: { kind: 'Service', name: 'system-developer' },
          tls: { insecureEdgeTerminationPolicy: 'Redirect', termination: 'edge' }
        },
        apiVersion: 'route.openshift.io/v1',
        kind: 'Route'
      }.to_json).
      to_return(status: 201, body: system_developer_route.to_json, headers: response_headers)

    route_list[:metadata][:resourceVersion] = '651342'
    route_list[:items] = [system_developer_route]

    stub_request(:get, 'http://localhost/apis/route.openshift.io/v1/namespaces/zync/routes').
      with(headers: request_headers).
      to_return(status: 200, body: route_list.to_json, headers: response_headers)

    stub_request(:get, "http://localhost/apis/route.openshift.io/v1/namespaces/zync/routes/#{system_developer_route.dig(:metadata, :name)}").
      with(headers: request_headers).
      to_return(status: 200, body: system_developer_route.to_json, headers: response_headers)

    # stub for creating provider route to system-provider
    system_provider_route_labels = provider_route_labels.merge('zync.3scale.net/route-to' => 'system-provider')
    system_provider_route_annotations = provider_route_annotations.merge('zync.3scale.net/host' => 'provider-admin.example.com')
    system_provider_route = {
      kind: 'Route',
      apiVersion: 'route.openshift.io/v1',
      metadata: {
        namespace: 'zync',
        name: 'zync-3scale-provider-rbpqw',
        uid: 'f741703c-7ca5-4480-8a32-074fcc759583',
        selfLink: '/apis/route.openshift.io/v1/namespaces/zync/routes/zync-3scale-provider-rbpqw',
        labels: system_developer_route_labels,
        annotations: system_developer_route_annotations
      },
      status: {}
    }

    stub_request(:get, "http://localhost/apis/route.openshift.io/v1/namespaces/zync/routes?labelSelector=3scale.net/created-by=zync,3scale.net/tenant_id=#{tenant_id},zync.3scale.net/record=#{record_gid},zync.3scale.net/route-to=system-provider").
      with(headers: request_headers).
      to_return(status: 200, body: route_list.merge(items: []).to_json, headers: response_headers)

    stub_request(:post, 'http://localhost/apis/route.openshift.io/v1/namespaces/zync/routes').
      with(headers: request_headers, body: {
        metadata: {
          generateName: 'zync-3scale-provider-',
          namespace: 'zync',
          labels: system_provider_route_labels,
          ownerReferences: [route_owner_reference],
          annotations: system_provider_route_annotations
        },
        spec: {
          host: 'provider-admin.example.com',
          port: { targetPort: 'http' },
          to: { kind: 'Service', name: 'system-provider' },
          tls: { insecureEdgeTerminationPolicy: 'Redirect', termination: 'edge' }
        },
        apiVersion: 'route.openshift.io/v1',
        kind: 'Route'
      }.to_json).
      to_return(status: 201, body: system_provider_route.to_json, headers: response_headers)

    route_list[:metadata][:resourceVersion] = '651343'
    route_list[:items] = [system_developer_route, system_provider_route]

    stub_request(:get, 'http://localhost/apis/route.openshift.io/v1/namespaces/zync/routes').
      with(headers: request_headers).
      to_return(status: 200, body: route_list.to_json, headers: response_headers)

    stub_request(:get, "http://localhost/apis/route.openshift.io/v1/namespaces/zync/routes/#{system_provider_route.dig(:metadata, :name)}").
      with(headers: request_headers).
      to_return(status: 200, body: system_provider_route.to_json, headers: response_headers)

    # create both routes
    assert_raises(Integration::KubernetesService::MissingStatusIngress) do
      service.call(entry)
    end
  end

  test 'owner reference controller' do
    replication_controller = { apiVersion: "v1", kind: "ReplicationController", name: "zync-que-1", uid: "252c094e-b23a-4b80-8d82-5ef1499a1771", controller: true, blockOwnerDeletion: true, metadata: { name: 'zync-que-1' } }
    pod = K8s::Resource.new(kind: 'Pod', apiVersion: 'v1', metadata: { name: 'zync-que-1', generateName: 'zync-que-', namespace: 'zync', selfLink: '/api/v1/namespaces/zync/pods/zync-que-123', uid: 'b145c845-7222-44ce-8d9d-f13b8f357de6', resourceVersion: '3620670', ownerReferences: [replication_controller.except(:metadata)] })

    stub_request(:get, 'http://localhost/api/v1').
      with(headers: request_headers).
      to_return(status: 200, body: {
        kind: 'APIResourceList',
        apiVersion: 'v1',
        groupVersion: 'apps.3scale.net/v1alpha1',
        resources: [
          { name: 'replicationcontrollers', singularName: '', namespaced: true, kind: 'ReplicationController', verbs: %w(get patch update) },
        ]
      }.to_json, headers: response_headers)

    stub_request(:get, 'http://localhost/api/v1/namespaces/zync/replicationcontrollers/zync-que-1').
      with(headers: request_headers).
      to_return(status: 200, body: K8s::Resource.new(replication_controller).to_json, headers: response_headers)

    owner_root = service.owner_reference_controller(pod)

    assert_equal 'ReplicationController', owner_root.kind
    assert_equal 'zync-que-1', owner_root.name
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

    test 'defaults to https when scheme is missing' do
      url = 'my-api.example.com'
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
    end
  end

  test 'create native ingress if not on openshift' do
    stub_request(:get, 'http://localhost/apis').
      with(headers: request_headers).
      to_return(status: 200, body: {
        kind: "APIGroupList",
        apiVersion: "v1",
        groups: [
          { name: "networking.k8s.io", versions: [{ groupVersion: "networking.k8s.io/v1", version: "v1" }], preferredVersion: { groupVersion: "networking.k8s.io/v1", version: "v1" } },
        ]
      }.to_json, headers: { 'Content-Type' => 'application/json' })
    
    proxy = entries(:proxy)

    stub_request(:get, 'http://localhost/apis/networking.k8s.io/v1').
      with(headers: request_headers).
      to_return(status: 200, body: k8s_networking_resource_list_response, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, 'http://localhost/apis/networking.k8s.io/v1/namespaces/zync/ingresses?labelSelector=3scale.net/created-by=zync,3scale.net/tenant_id=298486374,zync.3scale.net/record=Z2lkOi8venluYy9Qcm94eS8yOTg0ODYzNzQ,zync.3scale.net/ingress=proxy,3scale.net/service_id=2').
      with(headers: request_headers).
      to_return(status: 200, body: k8s_ingress_list_response, headers: { 'Content-Type' => 'application/json' })

    service.call(proxy)
  end

  test 'create native ingress if kubernetes_force_native_ingress' do
    Rails.application.config.integrations[:kubernetes_force_native_ingress] = true

    proxy = entries(:proxy)

    stub_request(:get, 'http://localhost/apis/networking.k8s.io/v1').
      with(headers: request_headers).
      to_return(status: 200, body: k8s_networking_resource_list_response, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, 'http://localhost/apis/networking.k8s.io/v1/namespaces/zync/ingresses?labelSelector=3scale.net/created-by=zync,3scale.net/tenant_id=298486374,zync.3scale.net/record=Z2lkOi8venluYy9Qcm94eS8yOTg0ODYzNzQ,zync.3scale.net/ingress=proxy,3scale.net/service_id=2').
      with(headers: request_headers).
      to_return(status: 200, body: k8s_ingress_list_response, headers: { 'Content-Type' => 'application/json' })

    service.call(proxy)
  end

  class IngressSpec < ActiveSupport::TestCase
    test 'secure ingresses' do
      url = 'https://my-api.example.com'
      service_name = 'My API'
      port = 7443
      tenant_id = '2'
      spec = Integration::KubernetesService::IngressSpec.new(url, service_name, port, tenant_id)
      json = {
        rules: [{
          host: "my-api.example.com",
          http: {
            paths: [{ path: '/', pathType: 'Prefix', backend: { service: { name: service_name, port: { name: port } } } }]
          }
        }],
        tls: [{hosts: ["my-api.example.com"], secretName: "My API-tls-2"}]
      }
      assert_equal json, spec.to_hash

      url = 'http://my-api.example.com'
      service_name = 'My API'
      port = 7780
      tenant_id = '2'
      spec = Integration::KubernetesService::IngressSpec.new(url, service_name, port, tenant_id)
      json = {
        rules: [{
          host: "my-api.example.com",
          http: {
            paths: [{ path: '/', pathType: 'Prefix', backend: { service: { name: service_name, port: { name: port } } } }]
          }
        }],
        tls: nil
      }
      assert_equal json, spec.to_hash
    end

    test 'defaults to https when scheme is missing' do
      url = 'my-api.example.com'
      service_name = 'My API'
      port = 7443
      tenant_id = '2'
      spec = Integration::KubernetesService::IngressSpec.new(url, service_name, port, tenant_id)
      json = {
        rules: [{
          host: "my-api.example.com",
          http: {
            paths: [{ path: '/', pathType: 'Prefix', backend: { service: { name: service_name, port: { name: port } } } }]
          }
        }],
        tls: [{hosts: ["my-api.example.com"], secretName: "My API-tls-2"}]
      }
      assert_equal json, spec.to_hash
    end
  end
  
  protected

  def request_headers
    {
      'Accept' => 'application/json',
      'Authorization' => 'Bearer token',
      'Host' => 'localhost:80'
    }
  end

  def response_headers
    { 'Content-Type' => 'application/json' }
  end

  def k8s_networking_resource_list_response
    {
      kind: "APIResourceList",
      apiVersion: "v1",
      groupVersion: "networking.k8s.io/v1",
      resources: [
        { name: "ingressclasses", singularName: "", namespaced: false, kind: "IngressClass", verbs: ["create","delete","deletecollection","get","list","patch","update","watch"], storageVersionHash: "6upRfBq0FOI=" },
        { name: "ingresses", singularName: "", namespaced: true, kind: "Ingress", verbs: ["create","delete","deletecollection","get","list","patch","update","watch"], shortNames: ["ing"], storageVersionHash: "ZOAfGflaKd0=" }, 
        { name: "ingresses/status", singularName: "", namespaced:true, kind: "Ingress", verbs: ["get","patch","update"] }, 
        { name: "networkpolicies", singularName: "", namespaced: true, kind: "NetworkPolicy", verbs: ["create","delete","deletecollection","get","list","patch","update","watch"], shortNames: ["netpol"], storageVersionHash: "YpfwF18m1G8=" },
      ]
    }.to_json
  end

  def k8s_ingress_list_response
    {
      kind: 'IngressList',
      apiVersion: 'networking.k8s.io/v1',
      metadata: { selfLink: '/apis/networking.k8s.io/v1/namespaces/zync/ingresses', resourceVersion: '651341' },
      items: []
    }.to_json
  end
end
