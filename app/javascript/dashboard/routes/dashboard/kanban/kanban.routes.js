import { frontendURL } from '../../../helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

const KanbanBoard = () => import('./KanbanBoard.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/kanban'),
      name: 'kanban_board',
      component: KanbanBoard,
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
        featureFlag: FEATURE_FLAGS.KANBAN,
      },
    },
  ],
};
