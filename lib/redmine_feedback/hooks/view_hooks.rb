module RedmineFeedback
  module Hooks
    class ViewHooks < Redmine::Hook::ViewListener
      render_on :view_issues_show_description_bottom, partial: 'feedback/issue_feedback'
      
      def view_layouts_base_html_head(context = {})
        stylesheet_link_tag('feedback', plugin: 'redmine_feedback') +
        javascript_include_tag('feedback', plugin: 'redmine_feedback')
      end
    end
  end
end