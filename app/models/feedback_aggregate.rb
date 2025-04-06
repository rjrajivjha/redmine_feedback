# app/models/feedback_aggregate.rb
class FeedbackAggregate < ActiveRecord::Base
  belongs_to :issue
  
  validates :issue, presence: true
  
  # Add this method to recalculate all aggregates
  def self.recalculate_all
    # First, clear all existing aggregates to avoid stale data
    FeedbackAggregate.delete_all
    
    # Get all issues that have feedback
    issue_ids = Feedback.pluck(:issue_id).uniq
    
    # Update aggregates for each issue
    issue_ids.each do |id|
      issue = Issue.find_by(id: id)
      update_for_issue(issue) if issue
    end
    
    # Now handle parent issues that might not have direct feedback
    Issue.where(id: issue_ids).each do |issue|
      parent = issue.parent
      while parent
        update_for_issue(parent)
        parent = parent.parent
      end
    end
  end

  def self.update_for_issue(issue)
    # Get all feedback for this issue and its children
    descendant_ids = issue.descendants.pluck(:id)
    issue_ids = [issue.id] + descendant_ids
    all_feedback = Feedback.where(issue_id: issue_ids)
    
    # Calculate averages
    if all_feedback.any?
      aggregate = find_or_initialize_by(issue_id: issue.id)
      aggregate.feedback_count = all_feedback.count
      aggregate.avg_right_first_time = all_feedback.average(:right_first_time).to_f
      aggregate.avg_on_time_delivery = all_feedback.average(:on_time_delivery).to_f
      aggregate.avg_targets_met = all_feedback.average(:targets_met).to_f
      aggregate.avg_punched_above = all_feedback.average(:punched_above).to_f
      aggregate.avg_total = (aggregate.avg_right_first_time + aggregate.avg_on_time_delivery + 
                           aggregate.avg_targets_met + aggregate.avg_punched_above) / 4.0
      aggregate.save
    else
      # If no feedback exists, clean up any aggregate that might exist
      where(issue_id: issue.id).destroy_all
    end

    if issue.parent
      update_for_issue(issue.parent)
    end
    
  end
end