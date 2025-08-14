import { shallowMount } from '@vue/test-utils';
import { vi } from 'vitest';
import AgentSelectionModal from '../AgentSelectionModal.vue';
import agentsAPI from 'dashboard/api/agents';

// Mock the API
vi.mock('dashboard/api/agents', () => ({
  default: {
    getAgentTemplates: vi.fn(),
  },
}));

// Mock the composables
vi.mock('dashboard/composables', () => ({
  useAlert: () => ({
    error: vi.fn(),
    warning: vi.fn(),
  }),
}));

describe('AgentSelectionModal.vue', () => {
  const globalConfig = {
    global: {
      stubs: {
        'woot-modal-header': true,
        'woot-button': true,
        'woot-modal': true,
      },
      mocks: {
        $t: key => key,
      },
    },
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('template rendering', () => {
    it('renders three creation options', () => {
      agentsAPI.getAgentTemplates.mockResolvedValue({ data: [] });

      const wrapper = shallowMount(AgentSelectionModal, {
        ...globalConfig,
      });

      expect(wrapper.text()).toContain(
        'AGENT_MGMT.TEMPLATE_SELECTION.USE_TEMPLATE'
      );
      expect(wrapper.text()).toContain(
        'AGENT_MGMT.TEMPLATE_SELECTION.CREATE_FROM_SCRATCH'
      );
      expect(wrapper.text()).toContain(
        'AGENT_MGMT.TEMPLATE_SELECTION.CREATE_WITH_AI'
      );
    });

    it('displays templates when available', async () => {
      const mockTemplates = [
        {
          id: 1,
          name: 'Customer Service',
          description: 'For customer support',
          instructions: 'Be helpful',
        },
        {
          id: 2,
          name: 'Sales',
          description: 'For sales inquiries',
          instructions: 'Be persuasive',
        },
      ];
      agentsAPI.getAgentTemplates.mockResolvedValue({ data: mockTemplates });

      const wrapper = shallowMount(AgentSelectionModal, {
        ...globalConfig,
      });

      await wrapper.vm.$nextTick();
      await wrapper.vm.$nextTick(); // Wait for API call

      expect(wrapper.text()).toContain('Customer Service');
      expect(wrapper.text()).toContain('Sales');
    });

    it('shows no templates message when empty', async () => {
      agentsAPI.getAgentTemplates.mockResolvedValue({ data: [] });

      const wrapper = shallowMount(AgentSelectionModal, {
        ...globalConfig,
      });

      await wrapper.vm.$nextTick();
      await wrapper.vm.$nextTick();

      expect(wrapper.text()).toContain(
        'AGENT_MGMT.TEMPLATE_SELECTION.NO_TEMPLATES'
      );
    });
  });

  describe('event emissions', () => {
    it('emits close event when cancelled', () => {
      agentsAPI.getAgentTemplates.mockResolvedValue({ data: [] });

      const wrapper = shallowMount(AgentSelectionModal, {
        ...globalConfig,
      });

      wrapper.vm.handleClose();

      expect(wrapper.emitted('close')).toBeTruthy();
    });

    it('emits createFromScratch event', () => {
      agentsAPI.getAgentTemplates.mockResolvedValue({ data: [] });

      const wrapper = shallowMount(AgentSelectionModal, {
        ...globalConfig,
      });

      wrapper.vm.handleCreateFromScratch();

      expect(wrapper.emitted('createFromScratch')).toBeTruthy();
    });

    it('emits createWithAI event', () => {
      agentsAPI.getAgentTemplates.mockResolvedValue({ data: [] });

      const wrapper = shallowMount(AgentSelectionModal, {
        ...globalConfig,
      });

      wrapper.vm.handleCreateWithAI();

      expect(wrapper.emitted('createWithAI')).toBeTruthy();
    });

    it('emits useTemplate event with selected template', () => {
      agentsAPI.getAgentTemplates.mockResolvedValue({ data: [] });

      const wrapper = shallowMount(AgentSelectionModal, {
        ...globalConfig,
      });

      const mockTemplate = { id: 1, name: 'Test Template' };
      wrapper.vm.selectedTemplate = mockTemplate;
      wrapper.vm.handleUseTemplate();

      expect(wrapper.emitted('useTemplate')).toBeTruthy();
      expect(wrapper.emitted('useTemplate')[0][0]).toEqual(mockTemplate);
    });
  });

  describe('API integration', () => {
    it('fetches templates on mount', () => {
      agentsAPI.getAgentTemplates.mockResolvedValue({ data: [] });

      shallowMount(AgentSelectionModal, {
        ...globalConfig,
      });

      expect(agentsAPI.getAgentTemplates).toHaveBeenCalled();
    });

    it('handles API errors gracefully', async () => {
      agentsAPI.getAgentTemplates.mockRejectedValue(new Error('API Error'));

      const wrapper = shallowMount(AgentSelectionModal, {
        ...globalConfig,
      });

      await wrapper.vm.$nextTick();
      await wrapper.vm.$nextTick();

      // Component should still render without crashing
      expect(wrapper.exists()).toBe(true);
    });
  });
});
