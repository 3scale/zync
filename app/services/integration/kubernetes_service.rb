# frozen_string_literal: true

class Integration::KubernetesService < Integration::ServiceBase
  attr_reader :namespace

  def initialize(integration, namespace: self.class.namespace)
    super(integration)
    @namespace = namespace
    @client = K8s::Client.autoconfig(namespace: namespace)
  end

  def self.namespace
    ENV.fetch('KUBERNETES_NAMESPACE') { File.read(File.join((ENV['TELEPRESENCE_ROOT'] || '/'), 'var/run/secrets/kubernetes.io/serviceaccount/namespace')) }
  end

  def call(entry)
    case entry.record
    when Proxy then handle_proxy(entry)
    when Provider then handle_provider(entry)
    end
  end

  def handle_proxy(entry)
    persist_proxy?(entry) ? persist_proxy(entry) : delete_proxy(entry)
  end

  def handle_provider(entry)
    persist?(entry) ? persist_provider(entry) : delete_provider(entry)
  end

  attr_reader :client

  def persist_proxy?(entry)
    entry.data&.dig('deployment_option') == 'hosted'
  end

  def persist?(entry)
    entry.data
  end

  def owner_reference_controller(resource)
    owner_references = resource.metadata.ownerReferences or return
    controller = owner_references.find(&:controller)
    controller.metadata = { namespace: namespace, name: controller.name }

    client.get_resource(controller)
  end

  def owner_reference_root(resource)
    while (owner = owner_reference_controller(resource))
      resource = owner
    end

    resource
  end

  def get_owner
    pod_name = ENV['KUBERNETES_POD_NAME'] || ENV['POD_NAME'] || ENV['HOSTNAME']

    pod = client.api('v1').resource('pods', namespace: namespace).get(pod_name)
    owner_reference_root(pod)
  end

  def as_reference(owner)
    K8s::API::MetaV1::OwnerReference.new(
      kind: owner.kind,
      apiVersion: owner.apiVersion,
      name: owner.metadata.name,
      uid: owner.metadata.uid
    )
  end

  def annotations_for(entry)
    {
      '3scale.net/gid': entry.to_gid.to_s
    }
  end

  def labels_for(entry)
    {
      '3scale.created-by': 'zync',
      '3scale.tenant_id': String(entry.tenant_id)
    }
  end

  def labels_for_proxy(entry)
    service_id = entry.last_known_data.fetch('service_id') { return }

    labels_for(entry).merge(
      '3scale.ingress': 'proxy',
      '3scale.service_id': String(service_id)
    )
  end

  def labels_for_provider(entry)
    provider_id = entry.last_known_data.fetch('id')

    labels_for(entry).merge(
      '3scale.ingress': 'provider',
      '3scale.provider_id': String(provider_id)
    )
  end

  class Route < K8s::Resource
    def initialize(attributes, **options)
      super attributes.with_indifferent_access
                      .merge(apiVersion: 'route.openshift.io/v1', kind: 'Route')
                      .reverse_merge(metadata: {}), **options
    end
  end

  class RouteSpec < K8s::Resource
    def initialize(url, service, port)
      uri = URI(url)
      super({
        host: uri.host || uri.path,
        port: { targetPort: port },
        tls: {
          insecureEdgeTerminationPolicy: 'Redirect',
          termination: 'edge'
        },
        to: {
          kind: 'Service',
          name: service
        }
      })
    end
  end

  def build_proxy_routes(entry)
    build_routes('zync-3scale-api-', [
                   RouteSpec.new(entry.data.fetch('endpoint'), 'apicast-production', 'gateway'),
                   RouteSpec.new(entry.data.fetch('sandbox_endpoint'), 'apicast-staging', 'gateway')
                 ], labels: labels_for_proxy(entry), annotations: annotations_for(entry))
  end

  def build_routes(name, specs = [], owner: get_owner, **metadata)
    specs.map do |spec|
      Route.new(
        metadata: {
          generateName: name,
          namespace: namespace,
          labels: owner.metadata.labels,
          ownerReferences: [as_reference(owner)]
        }.deep_merge(metadata),
        spec: spec
      )
    end
  end

  def build_provider_routes(entry)
    data = entry.data
    domain, admin_domain = data.values_at('domain', 'admin_domain')
    metadata = { labels: labels_for_provider(entry), annotations: annotations_for(entry) }

    if admin_domain == domain # master account
      build_routes('zync-3scale-master-', [
                     RouteSpec.new(data.fetch('domain'), 'system-master', 'http')
                   ], **metadata)
    else
      build_routes('zync-3scale-provider-', [
                     RouteSpec.new(data.fetch('domain'), 'system-developer', 'http'),
                     RouteSpec.new(data.fetch('admin_domain'), 'system-provider', 'http')
                   ], **metadata)
    end
  end

  def cleanup_but(list, label_selector)
    client
      .client_for_resource(list.first, namespace: namespace)
      .list(labelSelector: label_selector)
      .each do |resource|
      client.delete_resource(resource) unless list.include?(resource)
    end
  end

  protected def create_resources(list)
    list.map(&client.method(:create_resource))
  end

  def persist_proxy(entry)
    routes = build_proxy_routes(entry)
    routes = create_resources(routes)

    label_selector = labels_for_proxy(entry)

    cleanup_but(routes, label_selector)
  end

  def delete_proxy(entry)
    label_selector = labels_for_proxy(entry)

    cleanup_but([Route.new({})], label_selector)
  end

  def persist_provider(entry)
    routes = build_provider_routes(entry)
    routes = create_resources(routes)

    label_selector = labels_for_provider(entry)

    cleanup_but(routes, label_selector)
  end

  def delete_provider(entry)
    label_selector = labels_for_provider(entry)

    cleanup_but([Route.new({})], label_selector)
  end
end
