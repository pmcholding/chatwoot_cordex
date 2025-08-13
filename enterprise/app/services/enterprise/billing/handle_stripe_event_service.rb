class Enterprise::Billing::HandleStripeEventService
  CLOUD_PLANS_CONFIG = 'CHATWOOT_CLOUD_PLANS'.freeze

  # Plan hierarchy: Hacker (default) -> Startups -> Business -> Enterprise
  # Each higher tier includes all features from the lower tiers

  # Metadata keys that indicate a product uses the new metadata-based system
  METADATA_LIMIT_KEYS = %w[inboxes agents captain_responses captain_documents].freeze

  # Events we need to process (filters out irrelevant events)
  RELEVANT_EVENTS = %w[
    customer.subscription.created
    customer.subscription.updated
    customer.subscription.deleted
    invoice.payment_succeeded
    invoice.payment_failed
  ].freeze

  # Basic features available starting with the Startups plan
  STARTUP_PLAN_FEATURES = %w[
    inbound_emails
    help_center
    campaigns
    team_management
    channel_twitter
    channel_facebook
    channel_email
    channel_instagram
    captain_integration
  ].freeze

  # Additional features available starting with the Business plan
  BUSINESS_PLAN_FEATURES = %w[sla custom_roles].freeze

  # Additional features available only in the Enterprise plan
  ENTERPRISE_PLAN_FEATURES = %w[audit_logs disable_branding].freeze

  def perform(event:)
    @event = event

    # Filter only relevant events to avoid processing unnecessary webhooks
    return unless RELEVANT_EVENTS.include?(@event.type)

    case @event.type
    when 'customer.subscription.created', 'customer.subscription.updated'
      process_subscription_updated
    when 'customer.subscription.deleted'
      process_subscription_deleted
    when 'invoice.payment_succeeded'
      Rails.logger.info "Invoice payment succeeded for customer: #{subscription.customer}"
    when 'invoice.payment_failed'
      Rails.logger.warn "Invoice payment failed for customer: #{subscription.customer}"
    else
      Rails.logger.debug { "Unhandled event type: #{@event.type}" }
    end
  end

  private

  def process_subscription_updated
    return if account.blank?

    # Check if this is a new product with metadata
    if using_new_metadata_products?
      process_metadata_based_subscription
    else
      # Legacy processing for old products
      process_legacy_subscription
    end
  end

  def process_metadata_based_subscription
    Rails.logger.info "Processing metadata-based subscription for account #{account.id}"

    update_account_limits_from_metadata
    update_account_attributes_for_metadata_products
    reset_captain_usage
  end

  def process_legacy_subscription
    plan = find_plan(subscription['plan']['product']) if subscription['plan'].present?

    # skipping self hosted plan events
    return if plan.blank?

    update_account_attributes(subscription, plan)
    update_plan_features
    reset_captain_usage
  end

  def update_account_attributes(subscription, plan)
    # https://stripe.com/docs/api/subscriptions/object
    account.update(
      custom_attributes: {
        stripe_customer_id: subscription.customer,
        stripe_price_id: subscription['plan']['id'],
        stripe_product_id: subscription['plan']['product'],
        plan_name: plan['name'],
        subscribed_quantity: subscription['quantity'],
        subscription_status: subscription['status'],
        subscription_ends_on: Time.zone.at(subscription['current_period_end'])
      }
    )
  end

  def update_account_limits_from_metadata
    return if subscription['items']['data'].blank?

    price_id = subscription['items']['data'][0]['price']['id']

    begin
      # Retrieve price and product from Stripe to get metadata
      price = Stripe::Price.retrieve(price_id)
      product = Stripe::Product.retrieve(price.product)

      metadata = product.metadata

      # Update account limits based on product metadata dynamically
      limits = {}
      METADATA_LIMIT_KEYS.each do |key|
        limits[key] = metadata[key].to_i
      end

      account.update!(limits: limits)

      Rails.logger.info "Updated account #{account.id} limits from product #{product.id}: #{metadata}"
    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to retrieve Stripe product metadata: #{e.message}"
    end
  end

  def update_account_attributes_for_metadata_products
    return if subscription['items']['data'].blank?

    price_id = subscription['items']['data'][0]['price']['id']
    product_id = subscription['items']['data'][0]['price']['product']

    # Get product name from Stripe
    product_name = begin
      product = Stripe::Product.retrieve(product_id)
      product.name
    rescue Stripe::StripeError
      'Unknown Plan'
    end

    account.update!(
      custom_attributes: account.custom_attributes.merge({
                                                           stripe_customer_id: subscription.customer,
                                                           stripe_price_id: price_id,
                                                           stripe_product_id: product_id,
                                                           plan_name: product_name,
                                                           subscribed_quantity: subscription['quantity'] || 1,
                                                           subscription_status: subscription['status'],
                                                           subscription_ends_on: Time.zone.at(subscription['current_period_end'])
                                                         })
    )
  end

  def using_new_metadata_products?
    return false if subscription['items']['data'].blank?

    begin
      price_id = subscription['items']['data'][0]['price']['id']
      price = Stripe::Price.retrieve(price_id)
      product = Stripe::Product.retrieve(price.product)

      # Check if product has any of the metadata keys we use for limits
      # Convert Stripe metadata to hash to use key? method
      metadata = product.metadata.to_h
      METADATA_LIMIT_KEYS.any? { |key| metadata.key?(key) || metadata.key?(key.to_sym) }
    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to check product metadata: #{e.message}"
      false
    end
  end

  def process_subscription_deleted
    # skipping self hosted plan events
    return if account.blank?

    Enterprise::Billing::CreateStripeCustomerService.new(account: account).perform
  end

  def update_plan_features
    if default_plan?
      disable_all_premium_features
    else
      enable_features_for_current_plan
    end

    # Enable any manually managed features configured in internal_attributes
    enable_account_manually_managed_features

    account.save!
  end

  def disable_all_premium_features
    # Disable all features (for default Hacker plan)
    account.disable_features(*STARTUP_PLAN_FEATURES)
    account.disable_features(*BUSINESS_PLAN_FEATURES)
    account.disable_features(*ENTERPRISE_PLAN_FEATURES)
  end

  def enable_features_for_current_plan
    # First disable all premium features to handle downgrades
    disable_all_premium_features

    # Then enable features based on the current plan
    enable_plan_specific_features
  end

  def reset_captain_usage
    account.reset_response_usage
  end

  def enable_plan_specific_features
    plan_name = account.custom_attributes['plan_name']
    return if plan_name.blank?

    # Enable features based on plan hierarchy
    case plan_name
    when 'Startups'
      # Startups plan gets the basic features
      account.enable_features(*STARTUP_PLAN_FEATURES)
    when 'Business'
      # Business plan gets Startups features + Business features
      account.enable_features(*STARTUP_PLAN_FEATURES)
      account.enable_features(*BUSINESS_PLAN_FEATURES)
    when 'Enterprise'
      # Enterprise plan gets all features
      account.enable_features(*STARTUP_PLAN_FEATURES)
      account.enable_features(*BUSINESS_PLAN_FEATURES)
      account.enable_features(*ENTERPRISE_PLAN_FEATURES)
    end
  end

  def subscription
    @subscription ||= @event.data.object
  end

  def account
    return @account if defined?(@account)

    # Handle both Stripe object and Hash formats
    customer_id = subscription.respond_to?(:customer) ? subscription.customer : subscription['customer']

    @account = Account.where("custom_attributes->>'stripe_customer_id' = ?", customer_id).first

    # Fallback: try to find account by metadata if not found by customer_id
    if @account.blank? && subscription['metadata'] && subscription['metadata']['account_id']
      @account = Account.find_by(id: subscription['metadata']['account_id'])
    end

    @account
  end

  def find_plan(plan_id)
    cloud_plans = InstallationConfig.find_by(name: CLOUD_PLANS_CONFIG)&.value || []
    cloud_plans.find { |config| config['product_id'].include?(plan_id) }
  end

  def default_plan?
    cloud_plans = InstallationConfig.find_by(name: CLOUD_PLANS_CONFIG)&.value || []
    default_plan = cloud_plans.first || {}
    account.custom_attributes['plan_name'] == default_plan['name']
  end

  def enable_account_manually_managed_features
    # Get manually managed features from internal attributes using the service
    service = Internal::Accounts::InternalAttributesService.new(account)
    features = service.manually_managed_features

    # Enable each feature
    account.enable_features(*features) if features.present?
  end
end
