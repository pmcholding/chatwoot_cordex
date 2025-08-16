# Criar uma conversa adicional sem stage
account = Account.first
inbox = Inbox.find(1)
user = User.first

contact = Contact.create!(
  account: account,
  name: 'Cliente Sem Stage',
  email: 'sem.stage@exemplo.com',
  phone_number: '+5511999000000'
)

contact_inbox = ContactInbox.create!(
  contact: contact,
  inbox: inbox,
  source_id: SecureRandom.uuid
)

conversation = Conversation.create!(
  account: account,
  inbox: inbox,
  contact: contact,
  contact_inbox: contact_inbox,
  status: 'open',
  priority: 'medium',
  assignee: user,
  display_id: 1007,
  kanban_stage: nil  # Sem stage
)

Message.create!(
  account: account,
  inbox: inbox,
  conversation: conversation,
  message_type: 'incoming',
  content: 'Esta conversa não tem stage atribuído ainda. Precisa ser categorizada.',
  sender: contact
)

puts "✅ Conversa ##{conversation.display_id} criada SEM stage (unassigned)"
puts "Total de conversas: #{Conversation.count}"
puts "Conversas sem stage: #{Conversation.where(kanban_stage_id: nil).count}"
