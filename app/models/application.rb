# frozen_string_literal: true
class Application < ApplicationRecord
  belongs_to :tenant
  belongs_to :service

  def integration_model
    Model.find_by!(record: service)
  end
end
