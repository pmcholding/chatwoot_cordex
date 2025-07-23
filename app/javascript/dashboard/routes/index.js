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

  // Ensure account data is loaded by fetching specific account details if needed
  const accountId = to.params.accountId;
  if (accountId) {
    // Check if account data is already loaded in store
    const existingAccount = store.getters['accounts/getAccount'](
      Number(accountId)
    );

    // Only fetch if account data is missing or doesn't have custom_attributes
    if (!existingAccount || !existingAccount.custom_attributes) {
      try {
        await store.dispatch('accounts/show', accountId);
      } catch (error) {
        // Silent error - account data loading failed
      }
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
      return validateAuthenticateRoutePermission(to, next, store);
    });
  });
};

export default router;
