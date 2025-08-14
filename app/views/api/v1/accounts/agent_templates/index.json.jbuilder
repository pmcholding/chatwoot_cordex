json.array! @agent_templates do |template|
  json.id template.id
  json.name template.name
  json.description template.description
  json.instructions template.instructions
  json.account_id template.account_id
  json.created_at template.created_at
  json.updated_at template.updated_at
end