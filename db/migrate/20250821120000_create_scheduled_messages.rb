class CreateScheduledMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :scheduled_messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content, null: false
      t.datetime :scheduled_at, null: false
      t.integer :status, default: 0
      t.jsonb :metadata

      t.timestamps
    end

    add_index :scheduled_messages, [:status, :scheduled_at], name: 'idx_sched_msgs_status_time'
  end
end

