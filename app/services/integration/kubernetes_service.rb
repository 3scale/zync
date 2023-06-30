# frozen_string_literal: true

class Integration::KubernetesService < Integration::ServiceBase
  attr_reader :namespace

  class_attribute :maintain_tls_spec,
                  default: ActiveModel::Type::Boolean.new.cast(ENV['KUBERNETES_ROUTE_TLS'])

  def initialize(integration, namespace: self.class.namespace)
    super(integration)
    @namespace = namespace
    @client = K8s::Client.autoconfig(namespace: namespace).extend(MergePatch)
  end

  module MergePatch
    # @param resource [K8s::Resource]
    # @param attrs [Hash]
    # @return [K8s::Client]
    def merge_resource(resource, attrs)
      client_for_resource(resource).merge_patch(resource.metadata.name, attrs)
    end
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

    client.get_resource(controller.merge(metadata: { namespace: namespace, name: controller.name }))
  end

  def owner_reference_root(resource)
    while (owner = owner_reference_controller(resource))
      resource = owner
    end

    resource
  rescue K8s::Error::Forbidden
    # likely some resource like the operator
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
      '3scale.net/gid': entry.to_gid.to_s,
      'zync.3scale.net/gid': entry.model.record.to_gid.to_s,
    }
  end

  def label_selector_from(resource)
    resource.metadata.labels.to_h.with_indifferent_access.slice(
      '3scale.net/created-by', '3scale.net/tenant_id', 'zync.3scale.net/record', 'zync.3scale.net/route-to'
    )
  end

  def labels_for(entry)
    {
      '3scale.net/created-by': 'zync',
      '3scale.net/tenant_id': String(entry.tenant_id),
      'zync.3scale.net/record': entry.model.record.to_gid_param,
    }
  end

  def labels_for_proxy(entry)
    service_id = entry.last_known_data.fetch('service_id') { return }

    labels_for(entry).merge(
      'zync.3scale.net/ingress': 'proxy',
      '3scale.net/service_id': String(service_id)
    )
  end

  def labels_for_provider(entry)
    provider_id = entry.last_known_data.fetch('id')

    labels_for(entry).merge(
      'zync.3scale.net/ingress': 'provider',
      '3scale.net/provider_id': String(provider_id)
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
      tls_options = {
        insecureEdgeTerminationPolicy: 'Redirect',
        termination: 'edge'
      } if uri.class == URI::HTTPS || uri.scheme.blank?

      super({
        host: uri.host || uri.path,
        port: { targetPort: port },
        to: {
          kind: 'Service',
          name: service
        }
      }.merge(tls: tls_options))
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
      Route.new({
        metadata: {
          generateName: name,
          namespace: namespace,
          labels: owner.metadata.labels,
          ownerReferences: [as_reference(owner)]
        }.deep_merge(metadata.deep_merge(
          labels: {
            'zync.3scale.net/route-to': spec.to_h.dig(:to, :name),
          },
          annotations: {
            'zync.3scale.net/host': spec.host,
          }
        )),
        spec: spec
      })
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
      equal = list.any? { |object| object.metadata.uid === resource.metadata.uid && resource.metadata.selfLink == object.metadata.selfLink }
      Rails.logger.warn "Deleting #{resource.metadata} from k8s because it is not on #{list}"

      client.delete_resource(resource) unless equal
    end
  end

  def extract_route_patch(resource)
    {
      metadata: resource.metadata.to_h,
      spec: { host: resource.spec.host },
    }
  end

  protected def persist_resources(list)
    list.map do |resource|
      existing = client
                   .client_for_resource(resource, namespace: namespace)
                   .list(labelSelector: label_selector_from(resource))

      client.get_resource case existing.size
      when 0
        client.create_resource(resource)
      when 1
        update_resource(existing.first, resource)
      else
        existing.each(&client.method(:delete_resource))
        client.create_resource(resource)
                          end
    end
  end

  def cleanup_routes(routes)
    routes.each do |route|
      begin
        verify_route_status(route)
      rescue InvalidStatus => error
        # they need to be re-created anyway, OpenShift won't re-admit them
        client.delete_resource(route) if error.reason == 'HostAlreadyClaimed' && error.type == 'Admitted'
        raise
      end
    end
  end

  class InvalidStatus < StandardError
    attr_reader :type, :reason

    def initialize(condition)
      @type, @reason = condition.type, condition.reason
      super(condition.message)
    end
  end

  class MissingStatusIngress < InvalidStatus
    MISSING_STATUS_INGRESS_CONDITION = ActiveSupport::OrderedOptions.new.merge(type: 'unknown', reason: 'unknown', message: "Kubernetes resource status missing 'ingress' property").freeze

    def initialize
      super(MISSING_STATUS_INGRESS_CONDITION)
    end
  end

  def verify_route_status(route)
    ingress = (route.status.ingress or raise MissingStatusIngress).find { |ingress| ingress.host == route.spec.host }
    condition = ingress.conditions.find { |condition| condition.type == 'Admitted' }

    raise InvalidStatus, condition unless condition.status == 'True'
  end

  def update_resource(existing, resource)
    resource.spec.delete_field(:tls) if maintain_tls_spec?

    client.merge_resource(existing, resource)
  rescue K8s::Error::Invalid
    resource.spec.tls = existing.spec.tls if maintain_tls_spec?
    client.delete_resource(existing)
    client.create_resource(resource)
  end

  def persist_proxy(entry)
    routes = build_proxy_routes(entry)

    cleanup_routes persist_resources(routes)
  end

  def delete_proxy(entry)
    label_selector = labels_for_proxy(entry)

    cleanup_but([Route.new({})], label_selector)
  end

  def persist_provider(entry)
    routes = build_provider_routes(entry)

    cleanup_routes persist_resources(routes)
  end

  def delete_provider(entry)
    label_selector = labels_for_provider(entry)

    cleanup_but([Route.new({})], label_selector)
  end
end
