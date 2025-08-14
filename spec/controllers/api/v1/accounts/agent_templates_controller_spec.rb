require 'rails_helper'

RSpec.describe 'Agent Templates API', type: :request do
  let(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/{account.id}/agent_templates' do
    let!(:global_template) { create(:agent_template, name: 'Global Template') }
    let!(:account_template) { create(:agent_template, :with_account, account: account, name: 'Account Template') }
    let!(:other_account_template) { create(:agent_template, :with_account, name: 'Other Template') }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/agent_templates"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'returns available templates for the account' do
        get "/api/v1/accounts/#{account.id}/agent_templates",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        response_body = response.parsed_body
        expect(response_body.size).to eq(2)

        template_names = response_body.map { |t| t['name'] }
        expect(template_names).to contain_exactly('Account Template', 'Global Template')
      end

      it 'returns templates in correct JSON format' do
        get "/api/v1/accounts/#{account.id}/agent_templates",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        template = response.parsed_body.first

        expect(template).to have_key('id')
        expect(template).to have_key('name')
        expect(template).to have_key('description')
        expect(template).to have_key('instructions')
        expect(template).to have_key('account_id')
        expect(template).to have_key('created_at')
        expect(template).to have_key('updated_at')
      end
    end

    context 'when it is an admin user' do
      it 'returns available templates for the account' do
        get "/api/v1/accounts/#{account.id}/agent_templates",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body.size).to eq(2)
      end
    end
  end
end
