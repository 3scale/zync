# frozen_string_literal: true
class Model < ApplicationRecord
  belongs_to :tenant
  belongs_to :record, polymorphic: true

  has_many :entries
end
