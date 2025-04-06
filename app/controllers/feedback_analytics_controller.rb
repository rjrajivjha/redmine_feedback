class FeedbackAnalyticsController < ApplicationController
  before_action :find_project_by_project_id, only: [:index, :team, :individual]
  before_action :authorize, only: [:index, :team, :individual]
  
  def index
    # Project-wise analytics
    @feedback_count = Feedback.joins(:issue)
                         .where(issues: { project_id: @project.id })
                         .count
    
    # Get average scores for the project
    @project_averages = calculate_averages(
      Feedback.joins(:issue).where(issues: { project_id: @project.id })
    )
    
    # Get monthly trend data
    @monthly_data = monthly_trend_data(@project.id)
    
    # Get top issues by feedback score
    @top_issues = Issue.includes(:feedback_aggregate,:status,:priority)
                     .where(project_id: @project.id)
                     .where.not(feedback_aggregates:{id:nil})
                     .order('feedback_aggregates.avg_total DESC')
                     .limit(5)

    # Get issues by lowest feedback score
    @bottom_issues = Issue.includes(:feedback_aggregate,:status,:priority)
                    .where(project_id: @project.id)
                    .where.not(feedback_aggregates:{id:nil})
                    .order('feedback_aggregates.avg_total ASC')
                    .limit(5) 
  end
  
  def team
    # Team-wise analytics
    @teams = User.joins(:members)
               .where(members: { project_id: @project.id })
               .group_by { |u| u.group_ids.present? ? Group.where(id: u.group_ids).pluck(:name).join(', ') : 'No Team' }
    
    @team_averages = {}
    @teams.each do |team_name, users|
      user_ids = users.map(&:id)
      feedbacks = Feedback.joins(:issue)
                      .where(issues: { project_id: @project.id, assigned_to_id: user_ids })
      
      @team_averages[team_name] = calculate_averages(feedbacks) if feedbacks.any?
    end
  end
  
  def individual
    @project = Project.find(params[:project_id])
    
    # Get the metrics from settings - this is nil in your debug output
    @metrics = Setting.plugin_redmine_feedback['feedback_metrics'] || [
      {name: 'right_first_time', label: l(:label_feedback_accuracy), field_name: 'right_first_time'},
      {name: 'on_time_delivery', label: l(:label_feedback_promptness), field_name: 'on_time_delivery'},
      {name: 'targets_met', label: l(:label_feedback_targets), field_name: 'targets_met'},
      {name: 'punched_above', label: l(:label_feedback_punched_above), field_name: 'punched_above'}
    ]
    
    # Get the selected user or default to current user - this is empty in your debug output
    user_id = params[:user_id].present? ? params[:user_id].to_i : User.current.id
    @selected_user = User.find_by(id: user_id)
    
    # Initialize variables with default values
    @feedback_count = 0
    @user_averages = { total: 0 }
    @metrics.each do |metric|
      metric_name = metric['name'] || metric[:name]
      @user_averages[metric_name.to_sym] = 0
    end
    @monthly_data = { months: [] }
    @metrics.each do |metric|
      metric_name = metric['name'] || metric[:name]
      @monthly_data[metric_name] = []
    end
    @top_issues = []
    
    if @selected_user
      # Get feedback count for the user
      @feedback_count = Feedback.joins(:issue)
                           .where(issues: { project_id: @project.id, assigned_to_id: @selected_user.id })
                           .count
      
      if @feedback_count > 0
        # Get average scores for the user
        @user_averages = calculate_averages(
          Feedback.joins(:issue).where(issues: { project_id: @project.id, assigned_to_id: @selected_user.id })
        )
        
        # Get monthly trend data for the user
        @monthly_data = monthly_trend_data(@project.id, @selected_user.id)
        
        # Get top issues by feedback score for the user
        @top_issues = Issue.includes(:feedback_aggregate, :status, :priority)
                         .where(project_id: @project.id, assigned_to_id: @selected_user.id)
                         .where.not(feedback_aggregates: {id: nil})
                         .order('feedback_aggregates.avg_total DESC')
                         .limit(5)
      end
    end
  end
  
  
  private
  
  def calculate_averages(feedbacks)
    return nil unless feedbacks.any?
    
    # Get metrics from settings
    metrics = Setting.plugin_redmine_feedback['feedback_metrics'] || [
      {name: 'right_first_time', label: l(:label_feedback_accuracy), field_name: 'right_first_time'},
      {name: 'on_time_delivery', label: l(:label_feedback_promptness), field_name: 'on_time_delivery'},
      {name: 'targets_met', label: l(:label_feedback_targets), field_name: 'targets_met'},
      {name: 'punched_above', label: l(:label_feedback_punched_above), field_name: 'punched_above'}
    ]
    
    # Calculate averages for each metric
    averages = {}
    total_sum = 0
    metrics.each do |metric|
      field_name = metric['field_name'] || metric[:field_name]
      metric_name = metric['name'] || metric[:name]
      
      if feedbacks.column_names.include?(field_name)
        avg_value = feedbacks.average(field_name.to_sym).to_f.round(1)
        averages[metric_name.to_sym] = avg_value
        total_sum += avg_value
      end
    end
    
    # Calculate total average
    averages[:total] = metrics.length > 0 ? (total_sum / metrics.length).round(1) : 0
    
    averages
  end
  
  # Update the monthly_trend_data method to accept a user_id parameter
  def monthly_trend_data(project_id, user_id = nil)
    # Get data for the last 6 months
    start_date = 6.months.ago.beginning_of_month
    end_date = Date.today.end_of_month
    
    # Get metrics from settings
    metrics = Setting.plugin_redmine_feedback['feedback_metrics'] || [
      {name: 'right_first_time', label: l(:label_feedback_accuracy), field_name: 'right_first_time'},
      {name: 'on_time_delivery', label: l(:label_feedback_promptness), field_name: 'on_time_delivery'},
      {name: 'targets_met', label: l(:label_feedback_targets), field_name: 'targets_met'},
      {name: 'punched_above', label: l(:label_feedback_punched_above), field_name: 'punched_above'}
    ]
    
    # Build select clause for the query
    select_clause = ["DATE_TRUNC('month', feedbacks.created_at) as month", "COUNT(*) as count"]
    metrics.each do |metric|
      field_name = metric['field_name'] || metric[:field_name]
      select_clause << "AVG(#{field_name}) as avg_#{field_name}"
    end
    
    # Build the base query
    query = Feedback.joins(:issue)
               .where(issues: { project_id: project_id })
               .where('feedbacks.created_at BETWEEN ? AND ?', start_date, end_date)
    
    # Add user filter if specified
    query = query.where(issues: { assigned_to_id: user_id }) if user_id.present?
    
    # Group feedback by month and calculate averages
    monthly_data = query.group("DATE_TRUNC('month', feedbacks.created_at)")
                   .select(select_clause)
                   .order('month')
    
    # Format the data for the chart
    months = []
    metric_values = {}
    counts = []
    
    # Initialize metric values arrays
    metrics.each do |metric|
      field_name = metric['field_name'] || metric[:field_name]
      metric_values[field_name] = []
    end
    
    current_date = start_date
    while current_date <= end_date
      month_data = monthly_data.find { |d| d.month.to_date.beginning_of_month == current_date.to_date.beginning_of_month }
      
      months << current_date.strftime('%b %Y')
      if month_data
        metrics.each do |metric|
          field_name = metric['field_name'] || metric[:field_name]
          avg_method = "avg_#{field_name}"
          metric_values[field_name] << (month_data.respond_to?(avg_method) ? month_data.send(avg_method).to_f.round(1) : 0)
        end
        counts << month_data.count
      else
        metrics.each do |metric|
          field_name = metric['field_name'] || metric[:field_name]
          metric_values[field_name] << 0
        end
        counts << 0
      end
      
      current_date = current_date.next_month
    end
    
    # Prepare result hash
    result = { months: months, counts: counts }
    metrics.each do |metric|
      field_name = metric['field_name'] || metric[:field_name]
      name = metric['name'] || metric[:name]
      result[name.to_sym] = metric_values[field_name]
    end
    
    result
  end
end