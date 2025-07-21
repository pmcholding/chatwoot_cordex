class Enterprise::CreateTrialSubscriptionJob < ApplicationJob
  queue_as :default

  def perform(account)
    Enterprise::Billing::CreateTrialSubscriptionService.new(account: account).perform
  end
end
