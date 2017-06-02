class Notification < ApplicationRecord
  belongs_to :model
  belongs_to :tenant
end
