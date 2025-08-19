import * as types from '../mutation-types';
import KanbanSettingsAPI from '../../api/kanbanSettings';

const state = {
  record: null,
  uiFlags: {
    isFetching: false,
    isUpdating: false,
  },
};

export const getters = {
  getUIFlags($state) {
    return $state.uiFlags;
  },
  getSettings($state) {
    return $state.record || {};
  },
};

export const actions = {
  async get({ commit }) {
    commit(types.default.SET_KANBAN_SETTINGS_UI_FLAG, { isFetching: true });
    try {
      const { data } = await KanbanSettingsAPI.getSettings();
      commit(types.default.SET_KANBAN_SETTINGS, data);
    } finally {
      commit(types.default.SET_KANBAN_SETTINGS_UI_FLAG, { isFetching: false });
    }
  },

  async update({ commit }, params) {
    commit(types.default.SET_KANBAN_SETTINGS_UI_FLAG, { isUpdating: true });
    try {
      const { data } = await KanbanSettingsAPI.updateSettings(params);
      commit(types.default.SET_KANBAN_SETTINGS, data);
      return data;
    } finally {
      commit(types.default.SET_KANBAN_SETTINGS_UI_FLAG, { isUpdating: false });
    }
  },
};

export const mutations = {
  [types.default.SET_KANBAN_SETTINGS_UI_FLAG]($state, data) {
    $state.uiFlags = { ...$state.uiFlags, ...data };
  },
  [types.default.SET_KANBAN_SETTINGS]($state, data) {
    $state.record = data;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
