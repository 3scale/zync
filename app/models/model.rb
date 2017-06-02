class Model < ApplicationRecord
  belongs_to :tenant
  belongs_to :record, polymorphic: true
end
