# loading installation configs
GlobalConfig.clear_cache
ConfigLoader.new.process

## Seeds productions
if Rails.env.production?
  # Setup Onboarding flow
  Redis::Alfred.set(Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING, true)
end

## Seeds for Local Development
unless Rails.env.production?

  # Enables creating additional accounts from dashboard
  installation_config = InstallationConfig.find_by(name: 'CREATE_NEW_ACCOUNT_FROM_DASHBOARD')
  installation_config.value = true
  installation_config.save!

  # Set enterprise defaults for development
  plan_config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN')
  plan_config.value = 'enterprise'
  plan_config.save!

  quantity_config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')
  quantity_config.value = 9_999_999
  quantity_config.save!

  GlobalConfig.clear_cache

  account = Account.find_or_create_by!(name: 'Acme Inc')
  secondary_account = Account.find_or_create_by!(name: 'Acme Org')

  # Create default kanban stages for both accounts
  KanbanStage.create_default_stages_for_account!(account)
  KanbanStage.create_default_stages_for_account!(secondary_account)

  user = User.find_by(email: 'john@acme.inc')
  unless user
    user = User.new(name: 'John', email: 'john@acme.inc', password: 'Password1!', type: 'SuperAdmin')
    user.skip_confirmation!
    user.save!
  end

  AccountUser.find_or_create_by!(
    account_id: account.id,
    user_id: user.id
  ) do |account_user|
    account_user.role = :administrator
  end

  AccountUser.find_or_create_by!(
    account_id: secondary_account.id,
    user_id: user.id
  ) do |account_user|
    account_user.role = :administrator
  end

  web_widget = Channel::WebWidget.find_or_create_by!(account: account) do |widget|
    widget.website_url = 'https://acme.inc'
  end

  inbox = Inbox.find_or_create_by!(account: account, name: 'Acme Support') do |new_inbox|
    new_inbox.channel = web_widget
  end

  InboxMember.find_or_create_by!(user: user, inbox: inbox)

  contact_inbox = ContactInboxWithContactBuilder.new(
    source_id: user.id,
    inbox: inbox,
    hmac_verified: true,
    contact_attributes: { name: 'jane', email: 'jane@example.com', phone_number: '+2320000' }
  ).perform

  conversation = Conversation.create!(
    account: account,
    inbox: inbox,
    status: :open,
    assignee: user,
    contact: contact_inbox.contact,
    contact_inbox: contact_inbox,
    additional_attributes: {}
  )

  # sample email collect
  Seeders::MessageSeeder.create_sample_email_collect_message conversation

  Message.create!(content: 'Hello', account: account, inbox: inbox, conversation: conversation, sender: contact_inbox.contact,
                  message_type: :incoming)

  # sample location message
  #
  location_message = Message.new(content: 'location', account: account, inbox: inbox, sender: contact_inbox.contact, conversation: conversation,
                                 message_type: :incoming)
  location_message.attachments.new(
    account_id: account.id,
    file_type: 'location',
    coordinates_lat: 37.7893768,
    coordinates_long: -122.3895553,
    fallback_title: 'Bay Bridge, San Francisco, CA, USA'
  )
  location_message.save!

  # sample card
  Seeders::MessageSeeder.create_sample_cards_message conversation
  # input select
  Seeders::MessageSeeder.create_sample_input_select_message conversation
  # form
  Seeders::MessageSeeder.create_sample_form_message conversation
  # articles
  Seeders::MessageSeeder.create_sample_articles_message conversation
  # csat
  Seeders::MessageSeeder.create_sample_csat_collect_message conversation

  # Create additional conversations for Kanban testing
  puts 'Creating additional conversations for Kanban testing...'

  # Skip if we already have sample conversations
  if account.conversations.where('display_id >= ?', 2000).exists?
    puts 'Sample conversations already exist, skipping creation...'
  else
    kanban_stages = account.kanban_stages.ordered

    # Sample conversation data
    sample_conversations = [
      {
        contact_name: 'Maria Silva',
        contact_email: 'maria.silva@exemplo.com',
        contact_phone: '+5511999001001',
        priority: 'high',
        status: 'open',
        message: 'Estou com problemas para acessar minha conta. O sistema diz que minha senha está incorreta, mas tenho certeza que está correta.',
        stage_index: 0 # New
      },
      {
        contact_name: 'João Santos',
        contact_email: 'joao.santos@exemplo.com',
        contact_phone: '+5511999001002',
        priority: 'medium',
        status: 'open',
        message: 'Gostaria de saber mais sobre os planos disponíveis e seus preços. Podem me enviar uma proposta?',
        stage_index: 0 # New
      },
      {
        contact_name: 'Ana Costa',
        contact_email: 'ana.costa@exemplo.com',
        contact_phone: '+5511999001003',
        priority: 'urgent',
        status: 'open',
        message: 'Sistema fora do ar! Nossos clientes não conseguem acessar o portal. Preciso de ajuda urgente!',
        stage_index: 1 # In Progress
      },
      {
        contact_name: 'Carlos Oliveira',
        contact_email: 'carlos.oliveira@exemplo.com',
        contact_phone: '+5511999001004',
        priority: 'low',
        status: 'open',
        message: 'Seria possível adicionar uma funcionalidade de exportação em Excel nos relatórios?',
        stage_index: 2 # Review
      },
      {
        contact_name: 'Fernanda Lima',
        contact_email: 'fernanda.lima@exemplo.com',
        contact_phone: '+5511999001005',
        priority: 'medium',
        status: 'resolved',
        message: 'Problema com integração da API resolvido. Muito obrigada pelo suporte!',
        stage_index: 3 # Resolved
      },
      {
        contact_name: 'Roberto Ferreira',
        contact_email: 'roberto.ferreira@exemplo.com',
        contact_phone: '+5511999001006',
        priority: 'medium',
        status: 'open',
        message: 'Preciso de ajuda para configurar as notificações por email. Não estou recebendo os alertas.',
        stage_index: nil # Unassigned
      }
    ]

    sample_conversations.each_with_index do |conv_data, idx|
      # Create contact
      contact = Contact.create!(
        account: account,
        name: conv_data[:contact_name],
        email: conv_data[:contact_email],
        phone_number: conv_data[:contact_phone]
      )

      # Create contact inbox
      contact_inbox_sample = ContactInbox.create!(
        contact: contact,
        inbox: inbox,
        source_id: SecureRandom.uuid
      )

      # Determine kanban stage
      kanban_stage = conv_data[:stage_index] ? kanban_stages[conv_data[:stage_index]] : nil

      # Create conversation
      sample_conversation = Conversation.create!(
        account: account,
        inbox: inbox,
        contact: contact,
        contact_inbox: contact_inbox_sample,
        status: conv_data[:status],
        priority: conv_data[:priority],
        assignee: user,
        kanban_stage: kanban_stage,
        display_id: 2000 + idx + 1
      )

      # Create initial message
      Message.create!(
        account: account,
        inbox: inbox,
        conversation: sample_conversation,
        message_type: 'incoming',
        content: conv_data[:message],
        sender: contact
      )

      stage_name = kanban_stage ? kanban_stage.name : 'Unassigned'
      puts "  ✓ Conversation ##{sample_conversation.display_id} (#{conv_data[:contact_name]}) → #{stage_name}"
    end

    puts "✅ Created #{sample_conversations.length} additional conversations for Kanban testing"

    # Display final Kanban distribution
    puts "\n📊 Kanban Board Summary:"
    kanban_stages.each do |stage|
      count = stage.conversations.count
      puts "  #{stage.name}: #{count} conversations"
    end
    unassigned_count = account.conversations.where(kanban_stage_id: nil).count
    puts "  Unassigned: #{unassigned_count} conversations"
    puts "  Total: #{account.conversations.count} conversations"
  end

  CannedResponse.find_or_create_by!(account: account, short_code: 'start') do |response|
    response.content = 'Hello welcome to chatwoot.'
  end
end
