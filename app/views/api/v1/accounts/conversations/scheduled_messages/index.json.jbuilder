json.payload do
  json.array! @scheduled_messages do |sm|
    json.extract! sm, :id, :content, :scheduled_at, :status, :metadata
  end
end

