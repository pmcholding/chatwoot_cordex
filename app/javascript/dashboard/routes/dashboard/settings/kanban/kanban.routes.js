import { frontendURL } from '../../../../helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SettingsWrapper from '../SettingsWrapper.vue';

const KanbanSettings = () => import('../../kanban/KanbanSettings.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/kanban'),
      name: 'kanban_settings',
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'kanban_settings_index',
          component: KanbanSettings,
          meta: {
            permissions: ['administrator', 'agent', 'custom_role'],
            featureFlag: FEATURE_FLAGS.KANBAN,
          },
        },
      ],
    },
  ],
};