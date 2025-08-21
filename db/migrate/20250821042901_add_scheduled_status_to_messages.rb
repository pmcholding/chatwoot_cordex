class AddScheduledStatusToMessages < ActiveRecord::Migration[7.1]
  def up
    # The value 4 will be mapped to 'scheduled' automatically by ActiveRecord
    # No need to alter the column, just use the new value

    # Add index for performance of the background job
    execute <<-SQL
      CREATE INDEX index_messages_on_status_and_scheduled_at
      ON messages(status, (additional_attributes->>'scheduled_at'))
      WHERE status = 4;
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS index_messages_on_status_and_scheduled_at;"

    # Convert scheduled messages to sent (fallback)
    Message.where(status: 4).update_all(status: 0)
  end
end
