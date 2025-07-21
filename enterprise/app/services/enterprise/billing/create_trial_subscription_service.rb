class Enterprise::Billing::CreateTrialSubscriptionService
  pattr_initialize [:account!]

  TRIAL_PERIOD_DAYS = 7
  DEFAULT_TRIAL_PLAN = 'Cordex Starter'.freeze # Plano padrão para trial

  def perform
    return if existing_subscription? || trial_already_created?

    customer_id = prepare_customer_id
    subscription = create_trial_subscription(customer_id)

    update_account_with_trial_data(customer_id, subscription)

    Rails.logger.info "Trial subscription created for account #{account.id}: #{subscription.id}"
  rescue Stripe::StripeError => e
    Rails.logger.error "Failed to create trial subscription for account #{account.id}: #{e.message}"
    # Não falha a criação da conta se o Stripe falhar
    mark_trial_creation_failed(e.message)
  end

  private

  def existing_subscription?
    account.custom_attributes['stripe_customer_id'].present? &&
      account.custom_attributes['stripe_price_id'].present?
  end

  def trial_already_created?
    account.custom_attributes['trial_created_at'].present?
  end

  def prepare_customer_id
    customer_id = account.custom_attributes['stripe_customer_id']
    if customer_id.blank?
      customer = Stripe::Customer.create({
                                           name: account.name,
                                           email: billing_email,
                                           metadata: {
                                             account_id: account.id,
                                             created_via: 'trial_signup'
                                           }
                                         })
      customer_id = customer.id
    end
    customer_id
  end

  def create_trial_subscription(customer_id)
    Stripe::Subscription.create({
                                  customer: customer_id,
                                  items: [{
                                    price: trial_price_id,
                                    quantity: 1
                                  }],
                                  trial_period_days: TRIAL_PERIOD_DAYS,
                                  metadata: {
                                    account_id: account.id,
                                    trial_type: 'signup_trial'
                                  }
                                })
  end

  def update_account_with_trial_data(customer_id, subscription)
    trial_ends_at = TRIAL_PERIOD_DAYS.days.from_now

    account.update!(
      custom_attributes: account.custom_attributes.merge({
                                                           stripe_customer_id: customer_id,
                                                           stripe_price_id: subscription.items.data.first.price.id,
                                                           stripe_product_id: subscription.items.data.first.price.product,
                                                           stripe_subscription_id: subscription.id,
                                                           plan_name: DEFAULT_TRIAL_PLAN,
                                                           subscribed_quantity: subscription.items.data.first.quantity,
                                                           subscription_status: 'trialing',
                                                           subscription_ends_on: trial_ends_at.iso8601,
                                                           trial_created_at: Time.current.iso8601,
                                                           trial_ends_at: trial_ends_at.iso8601,
                                                           is_trial: true
                                                         }),
      limits: trial_limits
    )
  end

  def mark_trial_creation_failed(error_message)
    account.update!(
      custom_attributes: account.custom_attributes.merge({
                                                           trial_creation_failed: true,
                                                           trial_creation_error: error_message,
                                                           trial_creation_failed_at: Time.current.iso8601
                                                         })
    )
  end

  def billing_email
    account.administrators.first&.email || account.users.first&.email
  end

  def trial_price_id
    # Usar o price_id do plano Starter configurado no Stripe
    # Este deve ser configurado nas variáveis de ambiente
    ENV['STRIPE_TRIAL_PRICE_ID'] || default_trial_price_id
  end

  def default_trial_price_id
    # Fallback para um price_id padrão se não estiver configurado
    # Este deve ser o price_id do plano Starter no Stripe
    'price_1RnLcDIDmUcrOYuMcvvEvphJ' # Cordex Starter
  end

  def trial_limits
    # Limites do plano Starter para o período de trial
    {
      'inboxes' => 5,
      'agents' => 3,
      'captain_responses' => 200,
      'captain_documents' => 100
    }
  end
end
