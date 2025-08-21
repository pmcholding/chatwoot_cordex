class AddScheduledAtToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :scheduled_at, :datetime
  end
end
