import { createRouter, createWebHistory } from 'vue-router';

import { frontendURL } from '../helper/URLHelper';
import dashboard from './dashboard/dashboard.routes';
import store from 'dashboard/store';
import { validateLoggedInRoutes } from '../helper/routeHelpers';
import AnalyticsHelper from '../helper/AnalyticsHelper';

const routes = [...dashboard.routes];

export const router = createRouter({ history: createWebHistory(), routes });

export const validateAuthenticateRoutePermission = async (to, next) => {
  const { isLoggedIn, getCurrentUser: user } = store.getters;

  if (!isLoggedIn) {
    window.location.assign('/app/login');
    return '';
  }

  if (!to.name) {
    return next(frontendURL(`accounts/${user.account_id}/dashboard`));
  }

  // Ensure account data is loaded by fetching specific account details
  const accountId = to.params.accountId;
  if (accountId) {
    try {
      // Use the show method to get specific account data
      const response = await store.dispatch('accounts/show', accountId);
      // eslint-disable-next-line no-console
      console.log('✅ Account data loaded:', response);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Failed to load account data:', error);
    }
  }

  const nextRoute = validateLoggedInRoutes(to, store.getters.getCurrentUser);
  return nextRoute ? next(frontendURL(nextRoute)) : next();
};

export const initalizeRouter = () => {
  const userAuthentication = store.dispatch('setUser');

  router.beforeEach((to, _from, next) => {
    AnalyticsHelper.page(to.name || '', {
      path: to.path,
      name: to.name,
    });

    userAuthentication.then(async () => {
      return await validateAuthenticateRoutePermission(to, next, store);
    });
  });
};

export default router;
