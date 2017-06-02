class UsageLimit < ApplicationRecord
  belongs_to :metric
  belongs_to :tenant
end
