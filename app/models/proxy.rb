# frozen_string_literal: true

class Proxy < ApplicationRecord
  belongs_to :tenant
  belongs_to :service
end
