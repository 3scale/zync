# frozen_string_literal: true
class Integration < ApplicationRecord
  belongs_to :tenant
  belongs_to :model

  enum state: %i[active disabled].map{|status| [ status, status.to_s ] }.to_h

  def self.tenant_or_model(tenant, model)
    by_tenant = where(tenant: tenant, model_id: nil)
    by_model = model ? where(model_id: model.for_integration) : none

    by_tenant.or(by_model)
  end

  def self.for_model(model)
    tenant_or_model(model.tenant, model)
  end

  def enabled?
    Rails.application.config.integrations.fetch(self.class.name.demodulize.downcase, true)
  end
end
