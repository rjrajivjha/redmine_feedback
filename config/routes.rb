RedmineApp::Application.routes.draw do
  resources :projects do
    resources :feedback, only: [:index, :update, :destroy, :edit]
    get 'feedback_analytics', to: 'feedback_analytics#index'
    get 'feedback_analytics/team', to: 'feedback_analytics#team', as: 'feedback_analytics_team'
    get 'feedback_analytics/individual', to: 'feedback_analytics#individual', as: 'feedback_analytics_individual'
  end
  
  resources :issues do
    resources :feedback, only: [:new, :create,:edit, :update, :index, :destroy]
  end
  
  resources :feedback, only: [:edit, :update, :destroy]
end