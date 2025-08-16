# Script para criar conversas de exemplo no inbox 1

# Buscar dados necessários
account = Account.first
inbox = Inbox.find(1)
user = User.first

puts 'Criando conversas de exemplo...'

# Criar alguns contatos
contacts = []
5.times do |i|
  contact = Contact.create!(
    account: account,
    name: "Cliente #{i + 1}",
    email: "cliente#{i + 1}@exemplo.com",
    phone_number: "+5511999#{sprintf('%06d', i + 1)}"
  )
  contacts << contact
end

# Criar contact_inboxes
contact_inboxes = contacts.map do |contact|
  ContactInbox.create!(
    contact: contact,
    inbox: inbox,
    source_id: SecureRandom.uuid
  )
end

# Criar conversas com diferentes status e prioridades
conversations_data = [
  { 
    title: 'Problema com login na plataforma',
    status: 'open',
    priority: 'high',
    contact_idx: 0,
    message: 'Olá, estou tendo problemas para fazer login na plataforma. Sempre aparece erro de senha incorreta.'
  },
  { 
    title: 'Dúvida sobre faturamento',
    status: 'open', 
    priority: 'medium',
    contact_idx: 1,
    message: 'Gostaria de entender melhor como funciona o faturamento mensal. Podem me explicar?'
  },
  { 
    title: 'Solicitação de nova funcionalidade',
    status: 'open',
    priority: 'low', 
    contact_idx: 2,
    message: 'Seria possível adicionar uma funcionalidade de exportação em PDF nos relatórios?'
  },
  { 
    title: 'Bug no sistema de notificações',
    status: 'open',
    priority: 'urgent',
    contact_idx: 3, 
    message: 'As notificações não estão chegando no meu email. Já verifiquei spam e configurações.'
  },
  { 
    title: 'Integração com API externa',
    status: 'open',
    priority: 'medium',
    contact_idx: 4,
    message: 'Preciso de ajuda para integrar nossa API com o sistema de vocês. Têm documentação?'
  }
]

conversations_data.each_with_index do |conv_data, idx|
  conversation = Conversation.create!(
    account: account,
    inbox: inbox,
    contact: contacts[conv_data[:contact_idx]],
    contact_inbox: contact_inboxes[conv_data[:contact_idx]],
    status: conv_data[:status],
    priority: conv_data[:priority],
    assignee: user,
    display_id: 1000 + idx + 1
  )
  
  # Criar mensagem inicial
  Message.create!(
    account: account,
    inbox: inbox,
    conversation: conversation,
    message_type: 'incoming',
    content: conv_data[:message],
    sender: contacts[conv_data[:contact_idx]]
  )
  
  puts "Conversa criada: ##{conversation.display_id} - #{conv_data[:title]}"
end

puts "\n✅ Criadas #{conversations_data.length} conversas no inbox '#{inbox.name}'"
puts "Total de conversas no sistema: #{Conversation.count}"
