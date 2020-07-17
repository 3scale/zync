# frozen_string_literal: true

# Remove this when upgrading to Rails 6
module Rails6
  module ActiveRecord
    module Relation
      # File activerecord/lib/active_record/relation.rb, line 218
      def create_or_find_by!(attributes, &block)
        transaction(requires_new: true) { create!(attributes, &block) }
      rescue ::ActiveRecord::RecordNotUnique
        find_by!(attributes)
      end

      # File activerecord/lib/active_record/relation.rb, line 209
      def create_or_find_by(attributes, &block)
        transaction(requires_new: true) { create(attributes, &block) }
      rescue ::ActiveRecord::RecordNotUnique
        find_by!(attributes)
      end
    end
  end
end

ActiveRecord::Relation.prepend(Rails6::ActiveRecord::Relation)
