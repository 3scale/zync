class Entry < ApplicationRecord
  belongs_to :tenant
  belongs_to :model
end
