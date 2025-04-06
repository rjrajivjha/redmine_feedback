class CreateFeedbackAggregates < ActiveRecord::Migration[5.2]
  def change
    create_table :feedback_aggregates do |t|
      t.references :issue, null: false, index: { unique: true }
      t.integer :feedback_count, default: 0
      t.decimal :avg_right_first_time, precision: 4, scale: 2, default: 0
      t.decimal :avg_on_time_delivery, precision: 4, scale: 2, default: 0
      t.decimal :avg_targets_met, precision: 4, scale: 2, default: 0
      t.decimal :avg_punched_above, precision: 4, scale: 2, default: 0
      t.decimal :avg_total, precision: 4, scale: 2, default: 0
      
      t.timestamps
    end
  end
end