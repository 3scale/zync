# frozen_string_literal: true
class Client < ApplicationRecord
  belongs_to :service
  belongs_to :tenant

  validates :client_id, presence: true, uniqueness: { scope: :service_id }

  attr_readonly :client_id, :service_id, :tenant_id

  def self.for_service(service)
    where(service: service, tenant: service.tenant)
  end

  def integration_model
    Model.find_by(record: service)
  end
end
