require 'rails_helper'

RSpec.describe AgentTemplate, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:instructions) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:account).optional(true) }
  end

  describe 'scopes' do
    let(:account) { create(:account) }
    let(:other_account) { create(:account) }
    let!(:global_template) { create(:agent_template, account: nil) }
    let!(:account_template) { create(:agent_template, account: account) }
    let!(:other_account_template) { create(:agent_template, account: other_account) }

    describe '.global' do
      it 'returns only global templates' do
        expect(AgentTemplate.global).to contain_exactly(global_template)
      end
    end

    describe '.for_account' do
      it 'returns templates for specific account' do
        expect(AgentTemplate.for_account(account)).to contain_exactly(account_template)
      end
    end

    describe '.available_for' do
      it 'returns both global and account-specific templates' do
        expect(AgentTemplate.available_for(account)).to contain_exactly(global_template, account_template)
      end
    end
  end
end
