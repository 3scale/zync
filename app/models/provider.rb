# frozen_string_literal: true

class Provider < ApplicationRecord
  belongs_to :tenant
end
