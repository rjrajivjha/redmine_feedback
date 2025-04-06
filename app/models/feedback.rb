class Feedback < ActiveRecord::Base
  belongs_to :issue
  belongs_to :user
  
  serialize :company_values
  validates :issue, presence: true
  validates :user, presence: true
  
  # Get metrics from settings
  def self.metric_fields
    metrics = Setting.plugin_redmine_feedback['feedback_metrics'] || []
    metrics.map { |m| (m['field_name'] || m[:field_name]).to_sym }.compact
  end
  
  # Dynamic validations for metric fields
  validate :validate_metric_fields
  validate :validate_company_values
  validate :validate_comments_presence
  
  after_save :update_feedback_aggregate
  after_destroy :update_feedback_aggregate
  
  def validate_metric_fields
    # Get the metric fields from settings
    fields = self.class.metric_fields
    
    # If no metrics are configured, fall back to the default metrics
    if fields.empty?
      fields = [:right_first_time, :on_time_delivery, :targets_met, :punched_above]
    end
    
    # Validate presence and numericality for each field
    fields.each do |field|
      if self.respond_to?(field) && self.send(field).blank?
        errors.add(field, "can't be blank")
      end
      
      if self.respond_to?(field) && self.send(field).present?
        unless self.send(field).is_a?(Integer) && self.send(field) >= 1 && self.send(field) <= 10
          errors.add(field, "must be an integer between 1 and 10")
        end
      end
    end
  end
  
  def validate_company_values
    if company_values.present? && !company_values.is_a?(Array)
      errors.add(:company_values, "must be an array")
    end
  end
  
  def validate_comments_presence
    if (accuracy_described || promptness_described || targets_described || punched_above_described) && comments.blank?
      errors.add(:comments, "can't be blank when values are marked as described by assignee")
    end
  end
  
  def total_score
    # Get the metric fields from settings
    fields = self.class.metric_fields
    
    # If no metrics are configured, fall back to the default metrics
    if fields.empty?
      fields = [:right_first_time, :on_time_delivery, :targets_met, :punched_above]
    end
    
    # Calculate total score based on available fields
    fields.sum { |field| self.respond_to?(field) ? (self.send(field) || 0) : 0 }
  end
  
  def average_score
    # Get the metric fields from settings
    fields = self.class.metric_fields
    
    # If no metrics are configured, fall back to the default metrics
    if fields.empty?
      fields = [:right_first_time, :on_time_delivery, :targets_met, :punched_above]
    end
    
    # Count only fields that have values
    field_count = fields.count { |field| self.respond_to?(field) && self.send(field).present? }
    
    # Avoid division by zero
    return 0 if field_count == 0
    
    # Calculate average
    total_score.to_f / field_count
  end
  
  private
  
  def update_feedback_aggregate
    FeedbackAggregate.update_for_issue(issue)
    
    # Update parent issues if they exist
    update_parent_aggregates(issue)
  end
  
  def update_parent_aggregates(issue)
    if issue.parent
      # parent = Issue.find(issue.parent_issue_id)
      FeedbackAggregate.update_for_issue(issue.parent)
      update_parent_aggregates(issue.parent)
    end
  end
end

