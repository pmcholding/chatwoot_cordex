module Enterprise::Concerns::Account
  extend ActiveSupport::Concern

  included do
    has_many :sla_policies, dependent: :destroy_async
    has_many :applied_slas, dependent: :destroy_async
    has_many :custom_roles, dependent: :destroy_async

    has_many :captain_assistants, dependent: :destroy_async, class_name: 'Captain::Assistant'
    has_many :captain_assistant_responses, dependent: :destroy_async, class_name: 'Captain::AssistantResponse'
    has_many :captain_documents, dependent: :destroy_async, class_name: 'Captain::Document'

    has_many :copilot_threads, dependent: :destroy_async
    has_many :voice_channels, dependent: :destroy_async, class_name: '::Channel::Voice'

    # Criar trial automaticamente quando uma conta for criada
    after_create_commit :create_trial_subscription
  end

  # Métodos públicos para verificar status do trial
  def on_trial?
    custom_attributes['is_trial'] == true && trial_active?
  end

  def trial_active?
    return false if custom_attributes['trial_ends_at'].blank?

    trial_end_date = Time.zone.parse(custom_attributes['trial_ends_at'])
    Time.current < trial_end_date
  end

  def trial_expired?
    return false if custom_attributes['trial_ends_at'].blank?

    trial_end_date = Time.zone.parse(custom_attributes['trial_ends_at'])
    Time.current >= trial_end_date
  end

  def trial_days_remaining
    return 0 unless trial_active?

    trial_end_date = Time.zone.parse(custom_attributes['trial_ends_at'])
    ((trial_end_date - Time.current) / 1.day).ceil
  end

  def trial_status
    return 'no_trial' unless custom_attributes['is_trial']
    return 'active' if trial_active?
    return 'expired' if trial_expired?

    'unknown'
  end

  private

  def create_trial_subscription
    # Só criar trial se não estiver em ambiente de teste
    return if Rails.env.test?

    # Executar em background para não atrasar a criação da conta
    Enterprise::CreateTrialSubscriptionJob.perform_later(self)
  end
end
