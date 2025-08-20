<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import router from 'dashboard/routes';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';
import EvolutionWhatsappAPI from 'dashboard/api/evolutionWhatsapp';

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
      isCreating: false,
      showQRCode: false,
      qrCodeData: null,
      connectionStatus: 'disconnected',
      createdInboxId: null,
    };
  },
  computed: {
    ...mapGetters({ uiFlags: 'inboxes/getUIFlags' }),
    isConnecting() {
      return this.connectionStatus === 'connecting' || this.connectionStatus === 'disconnected';
    },
    isConnected() {
      return this.connectionStatus === 'connected';
    },
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

      this.isCreating = true;

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

        this.createdInboxId = evolutionChannel.id;
        this.showQRCode = true;
        await this.initializeConnection();
      } catch (error) {
        this.isCreating = false;
        useAlert(
          error.message ||
            this.$t('INBOX_MGMT.ADD.EVOLUTION_WHATSAPP.API.ERROR_MESSAGE')
        );
      }
    },

    async initializeConnection() {
      try {
        // Initialize Evolution API instance
        await EvolutionWhatsappAPI.initializeInstance(this.createdInboxId);

        // Get QR Code for connection
        await this.getQRCode();

        // Start polling for connection status
        this.pollConnectionStatus();
      } catch (error) {
        this.isCreating = false;
        useAlert(
          error.message || 'Erro ao inicializar conexão WhatsApp'
        );
      }
    },

    async getQRCode() {
      try {
        const response = await EvolutionWhatsappAPI.connectWithQRCode(this.createdInboxId);
        this.qrCodeData = response.data.qr_code;
      } catch (error) {
        console.error('Erro ao obter QR Code:', error);
      }
    },

    pollConnectionStatus() {
      const interval = setInterval(async () => {
        try {
          const response = await EvolutionWhatsappAPI.getConnectionStatus(this.createdInboxId);
          this.connectionStatus = response.data.status;

          if (this.connectionStatus === 'connected') {
            clearInterval(interval);
            this.isCreating = false;
            useAlert('WhatsApp conectado com sucesso!');

            // Redirect to add agents
            router.replace({
              name: 'settings_inboxes_add_agents',
              params: {
                page: 'new',
                inbox_id: this.createdInboxId,
              },
            });
          }
        } catch (error) {
          console.error('Erro ao verificar status:', error);
        }
      }, 3000); // Check every 3 seconds

      // Stop polling after 5 minutes
      setTimeout(() => {
        clearInterval(interval);
        if (this.connectionStatus !== 'connected') {
          this.isCreating = false;
          useAlert('Tempo limite para conexão excedido. Tente novamente.');
        }
      }, 300000);
    },

    skipConnection() {
      router.replace({
        name: 'settings_inboxes_add_agents',
        params: {
          page: 'new',
          inbox_id: this.createdInboxId,
        },
      });
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
      <!-- Step 1: Create Channel -->
      <div v-if="!showQRCode" class="flex flex-col gap-4">
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
                Conecte Imediatamente
              </h4>
              <p class="text-sm text-blue-700">
                Após criar a caixa de entrada, você poderá conectar seu WhatsApp imediatamente usando QR Code.
              </p>
            </div>
          </div>
        </div>

        <NextButton
          :is-loading="isCreating"
          :disabled="v$.inboxName.$invalid || isCreating"
          type="submit"
          solid
          blue
          :label="isCreating ? 'Criando e Conectando...' : $t('INBOX_MGMT.ADD.EVOLUTION_WHATSAPP.SUBMIT_BUTTON')"
        />
      </div>

      <!-- Step 2: QR Code Connection -->
      <div v-if="showQRCode" class="flex flex-col gap-6">
        <div class="text-center">
          <h4 class="text-xl font-medium mb-2">
            Conecte seu WhatsApp
          </h4>
          <p class="text-gray-600 mb-4">
            Escaneie o código QR abaixo com seu WhatsApp para conectar
          </p>
        </div>

        <!-- QR Code Display -->
        <div class="flex justify-center">
          <div class="p-6 bg-white border-2 border-gray-200 rounded-lg shadow-sm">
            <div v-if="qrCodeData" class="qr-code-container">
              <img :src="qrCodeData" alt="QR Code WhatsApp" class="w-64 h-64" />
            </div>
            <div v-else class="w-64 h-64 flex items-center justify-center bg-gray-100 rounded">
              <div class="text-center">
                <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-green-500 mx-auto mb-2"></div>
                <p class="text-sm text-gray-600">Gerando QR Code...</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Connection Status -->
        <div class="text-center">
          <div v-if="connectionStatus === 'connecting'" class="flex items-center justify-center gap-2">
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-green-500"></div>
            <span class="text-green-600">Aguardando conexão...</span>
          </div>
          <div v-else-if="connectionStatus === 'connected'" class="text-green-600">
            ✅ WhatsApp conectado com sucesso!
          </div>
          <div v-else class="text-gray-600">
            📱 Abra o WhatsApp e escaneie o código
          </div>
        </div>

        <!-- Instructions -->
        <div class="bg-blue-50 p-4 rounded-lg">
          <h5 class="font-medium text-blue-900 mb-2">Como conectar:</h5>
          <ol class="text-sm text-blue-800 space-y-1">
            <li>1. Abra o WhatsApp no seu celular</li>
            <li>2. Toque em "Mais opções" (⋮) > "Dispositivos conectados"</li>
            <li>3. Toque em "Conectar um dispositivo"</li>
            <li>4. Escaneie o código QR acima</li>
          </ol>
        </div>

        <!-- Action Buttons -->
        <div class="flex gap-3">
          <button
            @click="getQRCode"
            type="button"
            class="flex-1 px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
          >
            🔄 Gerar Novo QR Code
          </button>
          <button
            @click="skipConnection"
            type="button"
            class="flex-1 px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700"
          >
            Conectar Depois
          </button>
        </div>
      </div>
    </div>
  </form>
</template>
