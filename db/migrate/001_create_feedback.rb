class CreateFeedback < ActiveRecord::Migration[5.2]
  def change
    create_table :feedbacks do |t|
      t.references :issue, null: false, index: true
      t.references :user, null: false, index: true
      t.integer :right_first_time, null: false  # Accuracy (1-10)
      t.integer :on_time_delivery, null: false  # Promptness (1-10)
      t.integer :targets_met, null: false       # (1-10)
      t.integer :punched_above, null: false     # (1-10)
      
      # Checkboxes for values described by assignee
      t.boolean :accuracy_described, default: false
      t.boolean :promptness_described, default: false
      t.boolean :targets_described, default: false
      t.boolean :punched_above_described, default: false
      
      t.text :comments
      t.timestamps
    end
    
    # Add a composite unique index to prevent multiple feedbacks from same user on same issue
    add_index :feedbacks, [:issue_id, :user_id], unique: true
  end
end