FactoryBot.define do
  factory :agent_template do
    name { Faker::Name.name }
    description { Faker::Lorem.sentence }
    instructions { Faker::Lorem.paragraph }
    account { nil }

    trait :with_account do
      account { create(:account) }
    end
  end
end
