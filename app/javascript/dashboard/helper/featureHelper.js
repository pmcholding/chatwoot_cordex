const FEATURE_HELP_URLS = {
  agent_bots: null, // Disabled - was 'https://chwt.app/hc/agent-bots'
  agents: null, // Disabled - was 'https://chwt.app/hc/agents'
  audit_logs: null, // Disabled - was 'https://chwt.app/hc/audit-logs'
  campaigns: null, // Disabled - was 'https://chwt.app/hc/campaigns'
  canned_responses: null, // Disabled - was 'https://chwt.app/hc/canned'
  channel_email: null, // Disabled - was 'https://chwt.app/hc/email'
  channel_facebook: null, // Disabled - was 'https://chwt.app/hc/fb'
  custom_attributes: null, // Disabled - was 'https://chwt.app/hc/custom-attributes'
  dashboard_apps: null, // Disabled - was 'https://chwt.app/hc/dashboard-apps'
  help_center: null, // Disabled - was 'https://chwt.app/hc/help-center'
  inboxes: null, // Disabled - was 'https://chwt.app/hc/inboxes'
  integrations: null, // Disabled - was 'https://chwt.app/hc/integrations'
  labels: null, // Disabled - was 'https://chwt.app/hc/labels'
  macros: null, // Disabled - was 'https://chwt.app/hc/macros'
  message_reply_to: null, // Disabled - was 'https://chwt.app/hc/reply-to'
  reports: null, // Disabled - was 'https://chwt.app/hc/reports'
  sla: null, // Disabled - was 'https://chwt.app/hc/sla'
  team_management: null, // Disabled - was 'https://chwt.app/hc/teams'
  webhook: null, // Disabled - was 'https://chwt.app/hc/webhooks'
  billing: null, // Use Stripe Billing Portal instead
};

export function getHelpUrlForFeature(featureName) {
  return FEATURE_HELP_URLS[featureName];
}
