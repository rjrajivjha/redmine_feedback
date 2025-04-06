module RedmineFeedback
  module SettingsControllerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        # The correct method to patch is 'plugin' not 'plugin_settings'
        alias_method :plugin_without_feedback_metrics, :plugin
        alias_method :plugin, :plugin_with_feedback_metrics
      end
    end

    module InstanceMethods
      def plugin_with_feedback_metrics
        if request.post? && params[:id] == 'redmine_feedback' && params[:settings] && params[:settings][:deleted_metrics].present?
          handle_deleted_metrics(params[:settings][:deleted_metrics])
        end
        plugin_without_feedback_metrics
      end

      private

      def handle_deleted_metrics(deleted_metrics)
        deleted_metrics.each do |field_name|
          # Skip if the field doesn't exist
          next unless Feedback.column_names.include?(field_name)
          
          # Create a migration to remove the column
          ActiveRecord::Migration.new.remove_column :feedbacks, field_name
          
          # Also remove the column from feedback_aggregates if it exists
          if FeedbackAggregate.column_names.include?("avg_#{field_name}")
            ActiveRecord::Migration.new.remove_column :feedback_aggregates, "avg_#{field_name}"
          end
          
          # Recalculate all aggregates
          FeedbackAggregate.recalculate_all if FeedbackAggregate.respond_to?(:recalculate_all)
        end
      end
    end
  end
end

unless SettingsController.included_modules.include?(RedmineFeedback::SettingsControllerPatch)
  SettingsController.send(:include, RedmineFeedback::SettingsControllerPatch)
end