# frozen_string_literal: true
class Tenant < ApplicationRecord
  encrypts :access_token

  validates :endpoint, :access_token, presence: true, length: { maximum: 255 }

  has_many :integrations, inverse_of: :tenant

  def self.upsert(params)
    retry_record_not_unique do
      tenant = find_or_create_by(id: params.require(:id))
      tenant.update(params)
      tenant
    end
  end
end
