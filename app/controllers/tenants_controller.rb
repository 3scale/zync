# frozen_string_literal: true
class TenantsController < ApplicationController
  wrap_parameters Tenant
  rescue_from ActiveRecord::RecordNotUnique, with: :conflict

  def update
    respond_with(Tenant.upsert(tenant_params))
  end

  protected

  def conflict
    head :conflict
  end

  def tenant_params
    params.require(:tenant).permit(:id, :endpoint, :access_token)
  end
end
