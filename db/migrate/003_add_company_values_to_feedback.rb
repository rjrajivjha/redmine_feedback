class AddCompanyValuesToFeedback < ActiveRecord::Migration[5.2]
  def change
    add_column :feedbacks, :company_values, :text
  end
end