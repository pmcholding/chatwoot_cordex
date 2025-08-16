const delay = ms => new Promise(resolve => { setTimeout(resolve, ms); });

const mockStages = [
  { id: 1, name: 'New', color: '#3b82f6', position: 1, count: 2 },
  { id: 2, name: 'In Progress', color: '#f59e0b', position: 2, count: 1 },
  { id: 3, name: 'Review', color: '#10b981', position: 3, count: 0 },
  { id: 4, name: 'Resolved', color: '#6366f1', position: 4, count: 0 },
];

const mockCards = [
  { id: 101, stage_id: 1, title: 'Welcome email follow-up', assignee: 'John', labels: ['priority'], updated_at: '2025-01-16T10:00:00Z' },
  { id: 102, stage_id: 1, title: 'Bug: chat widget not loading', assignee: 'Jane', labels: ['bug'], updated_at: '2025-01-16T09:45:00Z' },
  { id: 103, stage_id: 2, title: 'Feature: canned responses grouping', assignee: 'Alex', labels: ['feature'], updated_at: '2025-01-16T08:20:00Z' },
];

const state = {
  stages: [],
  cardsByStage: {}, // { [stageId]: { items: [], loading: false, hasMore: true } }
  filters: { q: '' },
  ui: { isLoading: false },
};

export const getters = {
  orderedStages: $state => [...$state.stages].sort((a, b) => a.position - b.position),
  cardsForStage: $state => stageId => $state.cardsByStage[stageId]?.items || [],
  loadingForStage: $state => stageId => $state.cardsByStage[stageId]?.loading || false,
  hasMoreForStage: $state => stageId => $state.cardsByStage[stageId]?.hasMore || false,
  filters: $state => $state.filters,
};

export const actions = {
  async fetchInitial({ commit }) {
    commit('SET_LOADING', true);
    await delay(200);
    commit('SET_STAGES', mockStages);
    // seed cards per stage
    const grouped = mockStages.reduce((acc, s) => {
      acc[s.id] = { items: [], loading: false, hasMore: true };
      return acc;
    }, {});
    mockCards.forEach(c => grouped[c.stage_id].items.push(c));
    commit('SET_ALL_CARDS', grouped);
    commit('RECALC_COUNTS');
    commit('SET_LOADING', false);
  },

  async loadMore({ commit, getters: rootGetters }, { stageId }) {
    if (!rootGetters.hasMoreForStage(stageId)) return;
    commit('SET_STAGE_LOADING', { stageId, loading: true });
    await delay(300);
    // mock: stop after one extra batch
    commit('SET_STAGE_HAS_MORE', { stageId, hasMore: false });
    commit('SET_STAGE_LOADING', { stageId, loading: false });
  },

  async moveCard({ commit }, { cardId, fromStageId, toStageId, toIndex }) {
    // optimistic update
    commit('MOVE_CARD', { cardId, fromStageId, toStageId, toIndex });
    commit('RECALC_COUNTS');
    await delay(200);
    // assume success; rollback logic could be added here if needed
  },

  async createStage({ commit }, { name, color }) {
    await delay(150);
    commit('ADD_STAGE', { name, color });
  },

  async updateStage({ commit }, { id, name, color }) {
    await delay(150);
    commit('EDIT_STAGE', { id, name, color });
  },

  async deleteStage({ commit }, { id }) {
    await delay(150);
    commit('DELETE_STAGE', { id });
    commit('RECALC_COUNTS');
  },

  setFilter({ commit }, payload) {
    commit('SET_FILTER', payload);
  },
};

export const mutations = {
  SET_LOADING($state, flag) {
    $state.ui.isLoading = flag;
  },
  SET_STAGES($state, stages) {
    $state.stages = stages;
  },
  SET_ALL_CARDS($state, grouped) {
    $state.cardsByStage = grouped;
  },
  SET_STAGE_LOADING($state, { stageId, loading }) {
    $state.cardsByStage[stageId].loading = loading;
  },
  SET_STAGE_HAS_MORE($state, { stageId, hasMore }) {
    $state.cardsByStage[stageId].hasMore = hasMore;
  },
  MOVE_CARD($state, { cardId, fromStageId, toStageId, toIndex }) {
    const from = $state.cardsByStage[fromStageId]?.items || [];
    const to = $state.cardsByStage[toStageId]?.items || [];
    const idx = from.findIndex(c => c.id === cardId);
    if (idx === -1) return;
    const [card] = from.splice(idx, 1);
    card.stage_id = toStageId;
    if (typeof toIndex === 'number' && toIndex >= 0 && toIndex <= to.length) {
      to.splice(toIndex, 0, card);
    } else {
      to.push(card);
    }
  },
  ADD_STAGE($state, { name, color }) {
    const nextPos = ($state.stages.at(-1)?.position || 0) + 1;
    const nextId = Math.max(0, ...$state.stages.map(s => s.id)) + 1;
    const stage = { id: nextId, name, color, position: nextPos, count: 0 };
    $state.stages.push(stage);
    $state.cardsByStage[nextId] = { items: [], loading: false, hasMore: true };
  },
  EDIT_STAGE($state, { id, name, color }) {
    const stg = $state.stages.find(x => x.id === id);
    if (!stg) return;
    if (name) stg.name = name;
    if (color) stg.color = color;
  },
  DELETE_STAGE($state, { id }) {
    $state.stages = $state.stages.filter(s => s.id !== id);
    delete $state.cardsByStage[id];
  },
  SET_FILTER($state, payload) {
    $state.filters = { ...$state.filters, ...payload };
  },
  RECALC_COUNTS($state) {
    $state.stages = $state.stages.map(s => ({
      ...s,
      count: $state.cardsByStage[s.id]?.items?.length || 0,
    }));
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};

