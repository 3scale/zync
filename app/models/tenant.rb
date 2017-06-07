# frozen_string_literal: true
class Tenant < ApplicationRecord
  validates :endpoint, :access_token, presence: true, length: { maximum: 255 }

  has_many :integrations, inverse_of: :tenant
end
