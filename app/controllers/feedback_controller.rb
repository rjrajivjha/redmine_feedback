class FeedbackController < ApplicationController
  before_action :find_project_by_project_id, only: [:index], if: -> {params[:project_id].present?}
  before_action :find_issue, only: [:new, :create, :edit, :update, :index], if: -> {params[:issue_id].present?}
  before_action :authorize, only: [:index]
  before_action :find_feedback, only: [:edit, :update, :destroy]
  
  def index
    @limit = per_page_option
    
    if @project
      # Project-level feedback
      @feedback_count = Feedback.joins(:issue)
                             .where(issues: { project_id: @project.id })
                             .count
      @feedback_pages = Redmine::Pagination::Paginator.new @feedback_count, @limit, params[:page]
      @offset = @feedback_pages.offset
      @feedbacks = Feedback.joins(:issue)
                        .where(issues: { project_id: @project.id })
                        .includes(:issue, :user)
                        .order('issues.id DESC')
                        .limit(@limit)
                        .offset(@offset)
    elsif @issue
      # Issue-level feedback
      @project = @issue.project
      authorize
      
      @feedback_count = Feedback.where(issue_id: @issue.id).count
      @feedback_pages = Redmine::Pagination::Paginator.new @feedback_count, @limit, params[:page]
      @offset = @feedback_pages.offset
      @feedbacks = Feedback.where(issue_id: @issue.id)
                        .includes(:user)
                        .order('created_at DESC')
                        .limit(@limit)
                        .offset(@offset)
      
      render 'issue_feedback_index'
    else
      render_404
    end
  end
    # @limit = per_page_option
    # @feedback_count = Feedback.joins(:issue)
    #                        .where(issues: { project_id: @project.id })
    #                        .count
    # @feedback_pages = Redmine::Pagination::Paginator.new @feedback_count, @limit, params[:page]
    # @offset = @feedback_pages.offset
    # @feedbacks = Feedback.joins(:issue)
    #                   .where(issues: { project_id: @project.id })
    #                   .includes(:issue, :user)
    #                   .order('issues.id DESC')
    #                   .limit(@limit)
    #                   .offset(@offset)
            
  
  
  def new
    @feedback = Feedback.new(issue: @issue)
    
    # Check if user is allowed to provide feedback
    unless User.current == @issue.author || @issue.watcher_users.include?(User.current)
      flash[:error] = l(:notice_not_authorized_to_provide_feedback)
      redirect_to issue_path(@issue)
      return
    end
    
    # Check if issue is in the right status
    
    unless allowed_status_ids.include?(@issue.status_id)
      flash[:error] = l(:notice_feedback_not_allowed_for_status)
      redirect_to issue_path(@issue)
      return
    end
    
    # Check if user already provided feedback
    if Feedback.exists?(issue_id: @issue.id, user_id: User.current.id)
      flash[:warning] = l(:notice_feedback_already_submitted)
      redirect_to edit_issue_feedback_path(@issue)
      return
    end
  end
  
  def create
    @feedback = Feedback.new(feedback_params)
    @feedback.issue = @issue
    @feedback.user = User.current
    
    # Check if user is allowed to provide feedback
    unless User.current == @issue.author || @issue.watcher_users.include?(User.current)
      flash[:error] = l(:notice_not_authorized_to_provide_feedback)
      redirect_to issue_path(@issue)
      return
    end

    # Check if issue is in the right status
    
    unless allowed_status_ids.include?(@issue.status_id)
      flash[:error] = l(:notice_feedback_not_allowed_for_status)
      redirect_to issue_path(@issue)
      return
    end
    
    if @feedback.save
      flash[:notice] = l(:notice_feedback_created)
      redirect_to issue_path(@issue)
    else
      render :new
    end
  end
  
  def edit
    unless @feedback.user == User.current || User.current.admin?
      flash[:error] = l(:notice_not_authorized_to_edit_feedback)
      redirect_to issue_path(@issue)
      return
    end
  end
  
  def update
    unless @feedback.user == User.current || User.current.admin?
      flash[:error] = l(:notice_not_authorized_to_edit_feedback)
      redirect_to issue_path(@issue)
      return
    end
    
    if @feedback.update(feedback_params)
      flash[:notice] = l(:notice_feedback_updated)
      redirect_to issue_path(@issue)
    else
      render :edit
    end
  end
  
  def destroy
    # Only admins or the feedback creator can delete
    unless @feedback.user == User.current || User.current.admin?
      flash[:error] = l(:notice_not_authorized_to_delete_feedback)
      redirect_to issue_path(@feedback.issue)
      return
    end
    
    @feedback.destroy
    flash[:notice] = l(:notice_feedback_deleted)
    redirect_to issue_path(@feedback.issue)
  end
  
  private

  def find_issue
    @issue = Issue.find(params[:issue_id])
    @project = @issue.project
    # Add this line to ensure project authorization for issue-level actions
    authorize
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_feedback
    @feedback = Feedback.find(params[:id])
    @issue = @feedback.issue
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def feedback_params
    params.require(:feedback).permit(
      :right_first_time, :on_time_delivery, :targets_met, :punched_above,
      :comments, company_values: [],
    )
  end

  def allowed_status_ids
    ids = Setting.plugin_redmine_feedback['allowed_status_ids']||[]
    ids.map(&:to_i)
  end
  
  def can_provide_feedback?
    # Only allow reporter (issue creator) or watchers to provide feedback
    is_authorized_user = (User.current == @issue.author || @issue.watcher_users.include?(User.current))
    
    # Only allow feedback when issue is in certain statuses
    # Modify this array to include the status IDs that should allow feedback
    # Example: 5 might be "Resolved", 6 might be "Closed"
    is_allowed_status = allowed_status_ids.include?(@issue.status_id)
    
    # Both conditions must be true
    is_authorized_user && is_allowed_status
  end
end