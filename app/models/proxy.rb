class Proxy < ApplicationRecord
  belongs_to :tenant
  belongs_to :service
end
