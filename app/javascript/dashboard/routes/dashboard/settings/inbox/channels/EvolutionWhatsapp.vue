<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import router from 'dashboard/routes';
import NextButton from 'shared/components/Button/NextButton.vue';
import { useAlert } from 'dashboard/composables';

export default {
  components: {
    NextButton,
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      inboxName: '',
    };
  },
  computed: {
    ...mapGetters({ uiFlags: 'inboxes/getUIFlags' }),
  },
  validations: {
    inboxName: { required },
  },
  methods: {
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const evolutionChannel = await this.$store.dispatch(
          'inboxes/createChannel',
          {
            name: this.inboxName,
            channel: {
              type: 'api',
              webhook_url: '',
              additional_attributes: {
                channel_type: 'evolution_whatsapp',
              },
            },
          }
        );

        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: evolutionChannel.id,
          },
        });
      } catch (error) {
        useAlert(
          error.message ||
            this.$t('INBOX_MGMT.ADD.EVOLUTION_WHATSAPP.API.ERROR_MESSAGE')
        );
      }
    },
  },
};
</script>

<template>
  <form class="flex flex-wrap mx-0 mt-4" @submit.prevent="createChannel">
    <div class="w-full mb-4">
      <h3 class="text-lg font-medium text-n-slate-12 mb-2">
        {{ $t('INBOX_MGMT.ADD.EVOLUTION_WHATSAPP.TITLE') }}
      </h3>
      <p class="text-sm text-n-slate-10 mb-6">
        {{ $t('INBOX_MGMT.ADD.EVOLUTION_WHATSAPP.DESC') }}
      </p>
    </div>

    <div class="w-[65%] flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.inboxName.$error }">
        {{ $t('INBOX_MGMT.ADD.EVOLUTION_WHATSAPP.INBOX_NAME.LABEL') }}
        <input
          v-model.trim="inboxName"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.EVOLUTION_WHATSAPP.INBOX_NAME.PLACEHOLDER')
          "
        />
        <span v-if="v$.inboxName.$error" class="message">{{
          $t('INBOX_MGMT.ADD.EVOLUTION_WHATSAPP.INBOX_NAME.ERROR')
        }}</span>
      </label>
    </div>

    <div class="w-full mt-6">
      <div class="p-4 bg-blue-50 border border-blue-200 rounded-lg mb-4">
        <div class="flex items-start space-x-3">
          <div class="w-5 h-5 text-blue-600 mt-0.5">
            <svg fill="currentColor" viewBox="0 0 20 20">
              <path
                fill-rule="evenodd"
                d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
          <div>
            <h4 class="text-sm font-medium text-blue-800 mb-1">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION_WHATSAPP.INFO.TITLE') }}
            </h4>
            <p class="text-sm text-blue-700">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION_WHATSAPP.INFO.DESC') }}
            </p>
          </div>
        </div>
      </div>

      <NextButton
        :is-loading="uiFlags.isCreating"
        type="submit"
        solid
        blue
        :label="$t('INBOX_MGMT.ADD.EVOLUTION_WHATSAPP.SUBMIT_BUTTON')"
      />
    </div>
  </form>
</template>
