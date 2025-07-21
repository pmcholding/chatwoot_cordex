import { frontendURL } from '../../../../helper/URLHelper';
import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';
import SettingsWrapper from '../SettingsWrapper.vue';
import NewIndex from './NewIndex.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/billing'),
      meta: {
        permissions: ['administrator'],
        installationTypes: [
          INSTALLATION_TYPES.CLOUD,
          INSTALLATION_TYPES.COMMUNITY,
        ],
      },
      component: SettingsWrapper,
      props: {
        headerTitle: 'BILLING_SETTINGS.TITLE',
        icon: 'credit-card-person',
        showNewButton: false,
      },
      children: [
        {
          path: '',
          name: 'billing_settings_index',
          component: NewIndex,
          meta: {
            installationTypes: [
              INSTALLATION_TYPES.CLOUD,
              INSTALLATION_TYPES.COMMUNITY,
            ],
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
