# init.rb
require 'redmine'
require_dependency File.expand_path('../lib/redmine_feedback/patches/issue_patch', __FILE__)

# Add this line near the top of your init.rb file
require_dependency File.expand_path('../lib/redmine_feedback/settings_controller_patch', __FILE__)

Redmine::Plugin.register :redmine_feedback do
  name 'Redmine Feedback Plugin'
  author 'Rajiv kumar jha'
  description 'This plugin allows reporters, watchers, and stakeholders to provide feedback on any tracker type'
  version '0.1.0'
  url 'https://github.com/rjrajivjha/redmine_feedback'
  author_url 'https://github.com/rjrajivjha'
  

  # Add settings
  settings default: {
    'allowed_status_ids' => ['2']  # Default status IDs as strings
  }, partial: 'settings/redmine_feedback_settings'
  
  # Add permissions
  project_module :feedback do
    permission :view_feedback, { feedback: [:show, :index], feedback_analytics: [:index, :team, :individual]}
    permission :provide_feedback, { feedback: [:new, :create, :edit, :update, :destroy] }
    permission :manage_feedback, {
      feedback: [:index, :show, :new, :create, :edit, :update, :destroy],
      feedback_analytics: [:index, :team, :individual]
    }
  end
  
  # Add a menu item to the project menu
  menu :project_menu, :feedback, { controller: 'feedback', action: 'index' }, 
  caption: :label_feedback, after: :activity, param: :project_id
  # Add a menu item to the project menu
  menu :project_menu, :feedback_analytics, 
       { controller: 'feedback_analytics', action: 'index' }, 
       caption: :label_feedback_analytics, 
       param: :project_id,
       after: :feedback
end

# Create hooks for issue view
# require_dependency 'redmine_feedback/hooks/view_hooks'
require_dependency File.expand_path('../lib/redmine_feedback/hooks/view_hooks', __FILE__)
