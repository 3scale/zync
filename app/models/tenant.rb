class Tenant < ApplicationRecord
  validates :domain, :access_token, presence: true, length: { maximum: 255 }

  has_many :integrations, inverse_of: :tenant
end
