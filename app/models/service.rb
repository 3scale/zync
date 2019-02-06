# frozen_string_literal: true

class Service < ApplicationRecord
  belongs_to :tenant
  has_many :proxies
end
