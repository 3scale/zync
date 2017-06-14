# frozen_string_literal: true
class Tenant < ApplicationRecord
  validates :endpoint, :access_token, presence: true, length: { maximum: 255 }

  has_many :integrations, inverse_of: :tenant

  def self.upsert(params)
    retry_record_not_unique do
      tenant = lock.find_or_create_by(id: params.require(:id))
      tenant.update_attributes(params)
      tenant
    end
  end
end