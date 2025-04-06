module RedmineFeedback
  module Patches
    module IssuePatch
      def self.included(base)
        base.class_eval do
          has_one :feedback_aggregate, dependent: :destroy
          has_many :feedbacks, dependent: :destroy
        end
      end
    end
  end
end

unless Issue.included_modules.include?(RedmineFeedback::Patches::IssuePatch)
  Issue.send(:include, RedmineFeedback::Patches::IssuePatch)
end