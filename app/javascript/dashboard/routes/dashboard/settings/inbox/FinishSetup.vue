<script>
import EmptyState from '../../../../components/widgets/EmptyState.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import DuplicateInboxBanner from './channels/instagram/DuplicateInboxBanner.vue';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { useAlert } from 'dashboard/composables';
import EvolutionWhatsappAPI from 'dashboard/api/evolutionWhatsapp';
export default {
  components: {
    EmptyState,
    NextButton,
    DuplicateInboxBanner,
  },
  computed: {
    currentInbox() {
      return this.$store.getters['inboxes/getInbox'](
        this.$route.params.inbox_id
      );
    },
    isATwilioInbox() {
      return this.currentInbox.channel_type === 'Channel::TwilioSms';
    },
    // Check if a facebook inbox exists with the same instagram_id
    hasDuplicateInstagramInbox() {
      const instagramId = this.currentInbox.instagram_id;
      const facebookInbox =
        this.$store.getters['inboxes/getFacebookInboxByInstagramId'](
          instagramId
        );

      return (
        this.currentInbox.channel_type === INBOX_TYPES.INSTAGRAM &&
        facebookInbox
      );
    },

    isAEmailInbox() {
      return this.currentInbox.channel_type === 'Channel::Email';
    },
    isALineInbox() {
      return this.currentInbox.channel_type === 'Channel::Line';
    },
    isASmsInbox() {
      return this.currentInbox.channel_type === 'Channel::Sms';
    },
    isWhatsAppCloudInbox() {
      return (
        this.currentInbox.channel_type === 'Channel::Whatsapp' &&
        this.currentInbox.provider === 'whatsapp_cloud'
      );
    },
    isEvolutionWhatsAppInbox() {
      return (
        this.currentInbox.channel_type === 'Channel::Api' &&
        this.currentInbox.additional_attributes?.channel_type === 'evolution_whatsapp'
      );
    },
    // If the inbox is a whatsapp cloud inbox and the source is not embedded signup, then show the webhook details
    shouldShowWhatsAppWebhookDetails() {
      return (
        this.isWhatsAppCloudInbox &&
        this.currentInbox.provider_config?.source !== 'embedded_signup'
      );
    },
    message() {
      if (this.isATwilioInbox) {
        return `${this.$t('INBOX_MGMT.FINISH.MESSAGE')}. ${this.$t(
          'INBOX_MGMT.ADD.TWILIO.API_CALLBACK.SUBTITLE'
        )}`;
      }

      if (this.isASmsInbox) {
        return `${this.$t('INBOX_MGMT.FINISH.MESSAGE')}. ${this.$t(
          'INBOX_MGMT.ADD.SMS.BANDWIDTH.API_CALLBACK.SUBTITLE'
        )}`;
      }

      if (this.isALineInbox) {
        return `${this.$t('INBOX_MGMT.FINISH.MESSAGE')}. ${this.$t(
          'INBOX_MGMT.ADD.LINE_CHANNEL.API_CALLBACK.SUBTITLE'
        )}`;
      }

      if (this.isWhatsAppCloudInbox && this.shouldShowWhatsAppWebhookDetails) {
        return `${this.$t('INBOX_MGMT.FINISH.MESSAGE')}. ${this.$t(
          'INBOX_MGMT.ADD.WHATSAPP.API_CALLBACK.SUBTITLE'
        )}`;
      }

      if (this.isAEmailInbox && !this.currentInbox.provider) {
        return this.$t('INBOX_MGMT.ADD.EMAIL_CHANNEL.FINISH_MESSAGE');
      }

      if (this.currentInbox.web_widget_script) {
        return this.$t('INBOX_MGMT.FINISH.WEBSITE_SUCCESS');
      }

      return this.$t('INBOX_MGMT.FINISH.MESSAGE');
    },
  },
  data() {
    return {
      showQRCode: false,
      qrCodeData: null,
      connectionStatus: 'disconnected',
      isConnecting: false,
      pollingInterval: null,
    };
  },
  beforeUnmount() {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
    }
  },
  methods: {
    async startEvolutionConnection() {
      this.isConnecting = true;

      try {
        // Initialize Evolution API instance
        await EvolutionWhatsappAPI.initializeInstance(this.$route.params.inbox_id);

        // Get QR Code for connection
        await this.getQRCode();

        this.showQRCode = true;
        this.isConnecting = false;

        // Start polling for connection status
        this.pollConnectionStatus();
      } catch (error) {
        this.isConnecting = false;
        useAlert(error.message || 'Erro ao inicializar conexão WhatsApp');
      }
    },

    async getQRCode() {
      try {
        const response = await EvolutionWhatsappAPI.connectWithQRCode(this.$route.params.inbox_id);
        this.qrCodeData = response.data.qr_code;
      } catch (error) {
        console.error('Erro ao obter QR Code:', error);
        useAlert('Erro ao gerar QR Code. Tente novamente.');
      }
    },

    async refreshQRCode() {
      this.qrCodeData = null;
      await this.getQRCode();
    },

    pollConnectionStatus() {
      this.pollingInterval = setInterval(async () => {
        try {
          const response = await EvolutionWhatsappAPI.getConnectionStatus(this.$route.params.inbox_id);
          this.connectionStatus = response.data.status;

          if (this.connectionStatus === 'connected') {
            clearInterval(this.pollingInterval);
            useAlert('WhatsApp conectado com sucesso!');
          }
        } catch (error) {
          console.error('Erro ao verificar status:', error);
        }
      }, 3000); // Check every 3 seconds

      // Stop polling after 5 minutes
      setTimeout(() => {
        if (this.pollingInterval) {
          clearInterval(this.pollingInterval);
          if (this.connectionStatus !== 'connected') {
            useAlert('Tempo limite para conexão excedido. Você pode tentar conectar novamente depois.');
          }
        }
      }, 300000);
    },

    skipEvolutionConnection() {
      if (this.pollingInterval) {
        clearInterval(this.pollingInterval);
      }
      // Continue to normal finish flow
      this.showQRCode = false;
    },
  },
};
</script>

<template>
  <div
    class="w-full h-full col-span-6 p-6 overflow-auto border border-b-0 rounded-t-lg border-n-weak bg-n-solid-1"
  >
    <DuplicateInboxBanner
      v-if="hasDuplicateInstagramInbox"
      :content="$t('INBOX_MGMT.ADD.INSTAGRAM.NEW_INBOX_SUGGESTION')"
    />

    <!-- Evolution WhatsApp Connection Flow -->
    <div v-if="isEvolutionWhatsAppInbox && !showQRCode && connectionStatus !== 'connected'" class="flex flex-col items-center justify-center min-h-[60vh]">
      <div class="text-center max-w-md">
        <div class="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-6">
          <img src="/assets/images/dashboard/channels/whatsapp.png" alt="WhatsApp" class="w-12 h-12" />
        </div>
        <h2 class="text-2xl font-bold text-gray-900 mb-2">
          Caixa de Entrada Criada com Sucesso!
        </h2>
        <p class="text-gray-600 mb-6">
          Agora vamos conectar seu WhatsApp para começar a receber mensagens.
        </p>
        <button
          @click="startEvolutionConnection"
          :disabled="isConnecting"
          class="px-8 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50 mr-4"
        >
          <span v-if="isConnecting">Iniciando conexão...</span>
          <span v-else>🔗 Conectar WhatsApp Agora</span>
        </button>
        <button
          @click="skipEvolutionConnection"
          class="px-6 py-3 text-gray-600 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
        >
          Conectar Depois
        </button>
      </div>
    </div>

    <!-- Evolution WhatsApp QR Code Flow -->
    <div v-else-if="isEvolutionWhatsAppInbox && showQRCode && connectionStatus !== 'connected'" class="flex flex-col items-center justify-center min-h-[60vh]">
      <div class="w-full max-w-2xl space-y-6">
        <div class="text-center">
          <h2 class="text-2xl font-bold text-gray-900 mb-2">
            Conecte seu WhatsApp
          </h2>
          <p class="text-gray-600">
            Escaneie o código QR abaixo com seu WhatsApp para conectar
          </p>
        </div>

        <!-- QR Code Display -->
        <div class="flex justify-center">
          <div class="p-8 bg-white border-2 border-gray-200 rounded-xl shadow-lg">
            <div v-if="qrCodeData" class="qr-code-container">
              <img :src="qrCodeData" alt="QR Code WhatsApp" class="w-64 h-64" />
            </div>
            <div v-else class="w-64 h-64 flex items-center justify-center bg-gray-100 rounded-lg">
              <div class="text-center">
                <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-green-500 mx-auto mb-4"></div>
                <p class="text-gray-600">Gerando QR Code...</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Connection Status -->
        <div class="text-center py-4">
          <div v-if="connectionStatus === 'connecting'" class="flex items-center justify-center gap-2">
            <div class="animate-spin rounded-full h-5 w-5 border-b-2 border-green-500"></div>
            <span class="text-green-600 font-medium">Aguardando conexão...</span>
          </div>
          <div v-else class="text-gray-600">
            📱 Abra o WhatsApp e escaneie o código
          </div>
        </div>

        <!-- Instructions -->
        <div class="bg-blue-50 p-6 rounded-xl">
          <h3 class="font-semibold text-blue-900 mb-3">Como conectar:</h3>
          <ol class="text-blue-800 space-y-2">
            <li class="flex items-start">
              <span class="font-semibold mr-2">1.</span>
              <span>Abra o WhatsApp no seu celular</span>
            </li>
            <li class="flex items-start">
              <span class="font-semibold mr-2">2.</span>
              <span>Toque em "Mais opções" (⋮) > "Dispositivos conectados"</span>
            </li>
            <li class="flex items-start">
              <span class="font-semibold mr-2">3.</span>
              <span>Toque em "Conectar um dispositivo"</span>
            </li>
            <li class="flex items-start">
              <span class="font-semibold mr-2">4.</span>
              <span>Escaneie o código QR acima</span>
            </li>
          </ol>
        </div>

        <!-- Action Buttons -->
        <div class="flex gap-4 justify-center">
          <button
            @click="refreshQRCode"
            class="px-6 py-3 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors"
          >
            🔄 Gerar Novo QR Code
          </button>
          <button
            @click="skipEvolutionConnection"
            class="px-6 py-3 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors"
          >
            Conectar Depois
          </button>
        </div>
      </div>
    </div>

    <!-- Evolution WhatsApp Success -->
    <div v-else-if="isEvolutionWhatsAppInbox && connectionStatus === 'connected'" class="flex flex-col items-center justify-center min-h-[60vh]">
      <div class="text-center max-w-md">
        <div class="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-6">
          <svg class="w-10 h-10 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
          </svg>
        </div>
        <h2 class="text-2xl font-bold text-gray-900 mb-2">
          WhatsApp Conectado com Sucesso!
        </h2>
        <p class="text-gray-600 mb-6">
          Sua caixa de entrada está pronta para receber mensagens do WhatsApp.
        </p>
        <div class="flex gap-4 justify-center">
          <router-link
            :to="{
              name: 'settings_inbox_show',
              params: { inboxId: $route.params.inbox_id },
            }"
          >
            <NextButton
              outline
              slate
              :label="$t('INBOX_MGMT.FINISH.MORE_SETTINGS')"
            />
          </router-link>
          <router-link
            :to="{
              name: 'inbox_dashboard',
              params: { inboxId: $route.params.inbox_id },
            }"
          >
            <NextButton
              solid
              teal
              label="🎉 Ir para Caixa de Entrada"
            />
          </router-link>
        </div>
      </div>
    </div>

    <!-- Default Finish Flow for Other Channels -->
    <EmptyState
      v-else
      :title="$t('INBOX_MGMT.FINISH.TITLE')"
      :message="message"
      :button-text="$t('INBOX_MGMT.FINISH.BUTTON_TEXT')"
    >
      <div class="w-full text-center">
        <div class="my-4 mx-auto max-w-[70%]">
          <woot-code
            v-if="currentInbox.web_widget_script"
            :script="currentInbox.web_widget_script"
          />
        </div>
        <div class="w-[50%] max-w-[50%] ml-[25%]">
          <woot-code
            v-if="isATwilioInbox"
            lang="html"
            :script="currentInbox.callback_webhook_url"
          />
        </div>
        <div
          v-if="shouldShowWhatsAppWebhookDetails"
          class="w-[50%] max-w-[50%] ml-[25%]"
        >
          <p class="mt-8 font-medium text-slate-700 dark:text-slate-200">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.API_CALLBACK.WEBHOOK_URL') }}
          </p>
          <woot-code lang="html" :script="currentInbox.callback_webhook_url" />
          <p class="mt-8 font-medium text-n-slate-11">
            {{
              $t(
                'INBOX_MGMT.ADD.WHATSAPP.API_CALLBACK.WEBHOOK_VERIFICATION_TOKEN'
              )
            }}
          </p>
          <woot-code
            lang="html"
            :script="currentInbox.provider_config.webhook_verify_token"
          />
        </div>
        <div class="w-[50%] max-w-[50%] ml-[25%]">
          <woot-code
            v-if="isALineInbox"
            lang="html"
            :script="currentInbox.callback_webhook_url"
          />
        </div>
        <div class="w-[50%] max-w-[50%] ml-[25%]">
          <woot-code
            v-if="isASmsInbox"
            lang="html"
            :script="currentInbox.callback_webhook_url"
          />
        </div>
        <div
          v-if="isAEmailInbox && !currentInbox.provider"
          class="w-[50%] max-w-[50%] ml-[25%]"
        >
          <woot-code lang="html" :script="currentInbox.forward_to_email" />
        </div>
        <div class="flex justify-center gap-2 mt-4">
          <router-link
            :to="{
              name: 'settings_inbox_show',
              params: { inboxId: $route.params.inbox_id },
            }"
          >
            <NextButton
              outline
              slate
              :label="$t('INBOX_MGMT.FINISH.MORE_SETTINGS')"
            />
          </router-link>
          <router-link
            :to="{
              name: 'inbox_dashboard',
              params: { inboxId: $route.params.inbox_id },
            }"
          >
            <NextButton
              solid
              teal
              :label="$t('INBOX_MGMT.FINISH.BUTTON_TEXT')"
            />
          </router-link>
        </div>
      </div>
    </EmptyState>
  </div>
</template>
