class IntegrationState < ApplicationRecord
  belongs_to :model
  belongs_to :entry, required: false
  belongs_to :integration
end
