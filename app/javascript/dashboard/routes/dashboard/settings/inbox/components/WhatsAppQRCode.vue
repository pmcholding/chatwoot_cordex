<script>
import { useAlert } from 'dashboard/composables';
import SettingsSection from '../../../../../components/SettingsSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import WootSwitch from 'dashboard/components-next/switch/Switch.vue';
import EvolutionWhatsappAPI from '../../../../../api/evolutionWhatsapp';

export default {
  name: 'WhatsAppQRCode',
  components: {
    SettingsSection,
    NextButton,
    WootSwitch,
  },
  props: {
    // Used by parent component for API calls
    // eslint-disable-next-line vue/no-unused-properties
    inbox: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isInitializing: true,
      isConnectingQR: false,
      isConnectingPhone: false,
      isDisconnecting: false,
      isSavingSettings: false,
      showPhoneModal: false,
      phoneNumber: '',

      // Instance data
      instanceName: null,
      webhookUrl: null,
      connectionState: null,
      qrCode: null,
      pairingCode: null,

      // QR Code timer
      qrTimer: null,
      qrTimeLeft: 20,

      // Settings
      settings: {
        reject_call: false,
        msg_call: '',
        groups_ignore: false,
        always_online: false,
        read_messages: false,
        read_status: false,
        sync_full_history: false,
      },

      // Polling
      statusPollingInterval: null,
    };
  },
  computed: {
    isConnected() {
      return this.connectionState?.instance?.state === 'open';
    },
  },
  async mounted() {
    await this.initializeInstance();
    // Only check status once on initialization, no continuous polling
  },
  beforeUnmount() {
    this.stopStatusPolling();
    this.stopQRTimer();
  },
  methods: {
    async initializeInstance() {
      try {
        this.isInitializing = true;

        const response = await EvolutionWhatsappAPI.initializeInstance();
        const data = response.data;

        this.instanceName = data.instance_name;
        this.webhookUrl = data.webhook_url;
        this.connectionState = data.connection_state;

        // If connected, load settings
        if (this.isConnected && data.connection_state?.settings) {
          this.loadSettings(data.connection_state.settings);
        }

        useAlert(
          data.existing_instance
            ? this.$t('INBOX_MGMT.WHATSAPP_QR.INSTANCE_FOUND')
            : this.$t('INBOX_MGMT.WHATSAPP_QR.INSTANCE_CREATED')
        );
      } catch (error) {
        // Failed to initialize Evolution instance
        useAlert(
          error.response?.data?.error ||
            this.$t('INBOX_MGMT.WHATSAPP_QR.INITIALIZATION_ERROR')
        );
      } finally {
        this.isInitializing = false;
      }
    },

    async checkConnectionStatus() {
      try {
        const response = await EvolutionWhatsappAPI.getConnectionStatus();
        const data = response.data;

        this.connectionState = data.connection_state;

        // If connected, stop polling and clear QR/pairing code
        if (this.isConnected) {
          this.stopStatusPolling();
          this.clearQRCode();
          useAlert(this.$t('INBOX_MGMT.WHATSAPP_QR.CONNECTED'));

          // Load settings if available
          if (data.settings) {
            this.loadSettings(data.settings);
          }
        }
      } catch (error) {
        // Failed to check connection status
      }
    },

    async connectWithQRCode() {
      try {
        this.isConnectingQR = true;
        this.qrCode = null;
        this.pairingCode = null;

        const response = await EvolutionWhatsappAPI.connectQRCode();
        const data = response.data;

        this.qrCode = data.qr_code;
        this.pairingCode = data.pairing_code;

        // Start QR timer and connection polling
        this.startQRTimer();
        this.startStatusPolling();

        useAlert(this.$t('INBOX_MGMT.WHATSAPP_QR.QR_GENERATED'));
      } catch (error) {
        // Failed to generate QR code
        useAlert(
          error.response?.data?.error ||
            this.$t('INBOX_MGMT.WHATSAPP_QR.QR_ERROR')
        );
      } finally {
        this.isConnectingQR = false;
      }
    },

    // Phone number connection temporarily disabled - API not working
    /*
    async connectWithPhoneNumber() {
      try {
        this.isConnectingPhone = true;

        const response = await EvolutionWhatsappAPI.connectWithNumber(this.phoneNumber);
        const data = response.data;

        this.pairingCode = data.pairing_code;
        this.qrCode = null;
        this.showPhoneModal = false;
        this.phoneNumber = '';

        // Start polling to check for connection
        this.startStatusPolling();

        useAlert(this.$t('INBOX_MGMT.WHATSAPP_QR.PAIRING_CODE_GENERATED'));
      } catch (error) {
        console.error('Failed to connect with phone number:', error);
        useAlert(
          error.response?.data?.error ||
          this.$t('INBOX_MGMT.WHATSAPP_QR.PHONE_ERROR')
        );
      } finally {
        this.isConnectingPhone = false;
      }
    },
    */

    async disconnectInstance() {
      try {
        this.isDisconnecting = true;

        await EvolutionWhatsappAPI.disconnect();

        // Reset connection state
        this.connectionState = null;
        this.qrCode = null;
        this.pairingCode = null;

        useAlert(this.$t('INBOX_MGMT.WHATSAPP_QR.DISCONNECTED'));

        // Refresh connection status
        await this.checkConnectionStatus();
      } catch (error) {
        // Failed to disconnect instance
        useAlert(
          error.response?.data?.error ||
            this.$t('INBOX_MGMT.WHATSAPP_QR.DISCONNECT_ERROR')
        );
      } finally {
        this.isDisconnecting = false;
      }
    },

    async updateSettings() {
      try {
        this.isSavingSettings = true;

        await EvolutionWhatsappAPI.updateSettings(this.settings);

        useAlert(this.$t('INBOX_MGMT.WHATSAPP_QR.SETTINGS_SAVED'));
      } catch (error) {
        // Failed to update settings
        useAlert(
          error.response?.data?.error ||
            this.$t('INBOX_MGMT.WHATSAPP_QR.SETTINGS_ERROR')
        );
      } finally {
        this.isSavingSettings = false;
      }
    },

    loadSettings(settingsData) {
      this.settings = {
        reject_call: settingsData.reject_call || false,
        msg_call: settingsData.msg_call || '',
        groups_ignore: settingsData.groups_ignore || false,
        always_online: settingsData.always_online || false,
        read_messages: settingsData.read_messages || false,
        read_status: settingsData.read_status || false,
        sync_full_history: settingsData.sync_full_history || false,
      };

      // Show notification that settings were loaded from instance
      useAlert(this.$t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.LOADED_FROM_INSTANCE'));
    },

    startStatusPolling() {
      // Poll every 5 seconds
      this.statusPollingInterval = setInterval(() => {
        this.checkConnectionStatus();
      }, 5000);
    },

    stopStatusPolling() {
      if (this.statusPollingInterval) {
        clearInterval(this.statusPollingInterval);
        this.statusPollingInterval = null;
      }
    },

    startQRTimer() {
      this.qrTimeLeft = 20;
      this.qrTimer = setInterval(() => {
        this.qrTimeLeft -= 1;
        if (this.qrTimeLeft <= 0) {
          this.stopQRTimer();
          this.clearQRCode();
          useAlert(this.$t('INBOX_MGMT.WHATSAPP_QR.QR_EXPIRED'));
        }
      }, 1000);
    },

    stopQRTimer() {
      if (this.qrTimer) {
        clearInterval(this.qrTimer);
        this.qrTimer = null;
      }
    },

    clearQRCode() {
      this.qrCode = null;
      this.pairingCode = null;
      this.stopQRTimer();
      this.stopStatusPolling();
    },
  },
};
</script>

<template>
  <div class="mx-8">
    <!-- Loading State -->
    <div v-if="isInitializing" class="flex items-center justify-center py-8">
      <woot-spinner size="" />
      <span class="ml-2">{{ $t('INBOX_MGMT.WHATSAPP_QR.INITIALIZING') }}</span>
    </div>

    <!-- Main Content -->
    <div v-else>
      <!-- Connection Status Badge - moved to after connection buttons -->

      <!-- Instance Information section removed as requested -->

      <!-- Connection Section -->
      <SettingsSection
        v-if="!isConnected"
        :title="$t('INBOX_MGMT.WHATSAPP_QR.CONNECTION.TITLE')"
        :sub-title="$t('INBOX_MGMT.WHATSAPP_QR.CONNECTION.SUBTITLE')"
      >
        <div class="space-y-4">
          <!-- Connection Buttons and Status -->
          <div class="flex items-center justify-between">
            <div class="flex space-x-4">
              <NextButton
                :is-loading="isConnectingQR"
                @click="connectWithQRCode"
              >
                {{ $t('INBOX_MGMT.WHATSAPP_QR.CONNECT_QR') }}
              </NextButton>
              <!-- Phone number connection temporarily disabled - API not working -->
              <!--
              <NextButton
                variant="hollow"
                @click="showPhoneModal = true"
              >
                {{ $t('INBOX_MGMT.WHATSAPP_QR.CONNECT_PHONE') }}
              </NextButton>
              -->
            </div>

            <!-- Connection Status -->
            <div v-if="!isConnected && !qrCode">
              <div
                class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-red-100 text-red-800"
              >
                <div class="w-2 h-2 bg-red-400 rounded-full mr-2" />
                {{ $t('INBOX_MGMT.WHATSAPP_QR.NOT_CONNECTED') }}
              </div>
            </div>
          </div>

          <!-- QR Code Display -->
          <div v-if="qrCode" class="mt-6">
            <div class="flex items-center justify-between mb-4">
              <h4 class="text-lg font-medium">
                {{ $t('INBOX_MGMT.WHATSAPP_QR.SCAN_QR') }}
              </h4>
              <div class="flex items-center space-x-2">
                <div
                  class="w-8 h-8 rounded-full border-2 border-orange-500 flex items-center justify-center"
                >
                  <span class="text-sm font-bold text-orange-600">{{
                    qrTimeLeft
                  }}</span>
                </div>
                <span class="text-sm text-gray-600">{{
                  $t('INBOX_MGMT.WHATSAPP_QR.SECONDS_LEFT')
                }}</span>
              </div>
            </div>
            <div class="flex flex-col items-center space-y-4">
              <div class="p-4 bg-white border rounded-lg relative">
                <img :src="qrCode" alt="QR Code" class="w-64 h-64" />
                <!-- Progress bar -->
                <div
                  class="absolute bottom-0 left-0 right-0 h-1 bg-gray-200 rounded-b-lg overflow-hidden"
                >
                  <div
                    class="h-full bg-orange-500 transition-all duration-1000 ease-linear"
                    :style="{ width: `${(qrTimeLeft / 20) * 100}%` }"
                  />
                </div>
              </div>
              <p class="text-sm text-gray-600 text-center max-w-md">
                {{ $t('INBOX_MGMT.WHATSAPP_QR.QR_INSTRUCTIONS') }}
              </p>
            </div>
          </div>

          <!-- Pairing Code Display -->
          <div v-if="pairingCode && !qrCode" class="mt-6">
            <h4 class="text-lg font-medium mb-4">
              {{ $t('INBOX_MGMT.WHATSAPP_QR.PAIRING_CODE') }}
            </h4>
            <div class="flex flex-col items-center space-y-4">
              <div class="p-6 bg-gray-50 border rounded-lg">
                <span class="text-3xl font-mono font-bold tracking-wider">{{
                  pairingCode
                }}</span>
              </div>
              <p class="text-sm text-gray-600 text-center max-w-md">
                {{ $t('INBOX_MGMT.WHATSAPP_QR.PAIRING_INSTRUCTIONS') }}
              </p>
            </div>
          </div>
        </div>
      </SettingsSection>

      <!-- Connected Section -->
      <SettingsSection
        v-if="isConnected"
        :title="$t('INBOX_MGMT.WHATSAPP_QR.CONNECTED.TITLE')"
        :sub-title="$t('INBOX_MGMT.WHATSAPP_QR.CONNECTED.SUBTITLE')"
      >
        <div class="space-y-4">
          <div
            class="flex items-center justify-between p-4 bg-green-50 border border-green-200 rounded-lg"
          >
            <div class="flex items-center space-x-3">
              <div class="w-3 h-3 bg-green-500 rounded-full" />
              <span class="text-green-800 font-medium">
                {{ $t('INBOX_MGMT.WHATSAPP_QR.CONNECTED.STATUS') }}
              </span>
            </div>
            <NextButton
              variant="danger"
              :is-loading="isDisconnecting"
              @click="disconnectInstance"
            >
              {{ $t('INBOX_MGMT.WHATSAPP_QR.DISCONNECT') }}
            </NextButton>
          </div>
        </div>
      </SettingsSection>

      <!-- Settings Section (when connected) -->
      <SettingsSection
        v-if="isConnected"
        :title="$t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.TITLE')"
        :sub-title="$t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.SUBTITLE')"
      >
        <!-- Current Settings Status -->
        <div class="mb-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
          <div class="flex items-center space-x-2 mb-3">
            <div class="w-2 h-2 bg-blue-500 rounded-full" />
            <span class="text-sm font-medium text-blue-800">
              {{ $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.CURRENT_STATUS') }}
            </span>
          </div>
          <div class="grid grid-cols-2 gap-4 text-xs">
            <div class="space-y-1">
              <div class="flex justify-between">
                <span class="text-gray-600"
                  >{{
                    $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.REJECT_CALL')
                  }}:</span
                >
                <span
                  :class="
                    settings.reject_call ? 'text-green-600' : 'text-gray-500'
                  "
                >
                  {{
                    settings.reject_call ? $t('GENERAL.YES') : $t('GENERAL.NO')
                  }}
                </span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-600"
                  >{{
                    $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.GROUPS_IGNORE')
                  }}:</span
                >
                <span
                  :class="
                    settings.groups_ignore ? 'text-green-600' : 'text-gray-500'
                  "
                >
                  {{
                    settings.groups_ignore
                      ? $t('GENERAL.YES')
                      : $t('GENERAL.NO')
                  }}
                </span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-600"
                  >{{
                    $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.ALWAYS_ONLINE')
                  }}:</span
                >
                <span
                  :class="
                    settings.always_online ? 'text-green-600' : 'text-gray-500'
                  "
                >
                  {{
                    settings.always_online
                      ? $t('GENERAL.YES')
                      : $t('GENERAL.NO')
                  }}
                </span>
              </div>
            </div>
            <div class="space-y-1">
              <div class="flex justify-between">
                <span class="text-gray-600"
                  >{{
                    $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.READ_MESSAGES')
                  }}:</span
                >
                <span
                  :class="
                    settings.read_messages ? 'text-green-600' : 'text-gray-500'
                  "
                >
                  {{
                    settings.read_messages
                      ? $t('GENERAL.YES')
                      : $t('GENERAL.NO')
                  }}
                </span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-600"
                  >{{
                    $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.READ_STATUS')
                  }}:</span
                >
                <span
                  :class="
                    settings.read_status ? 'text-green-600' : 'text-gray-500'
                  "
                >
                  {{
                    settings.read_status ? $t('GENERAL.YES') : $t('GENERAL.NO')
                  }}
                </span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-600"
                  >{{
                    $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.SYNC_FULL_HISTORY')
                  }}:</span
                >
                <span
                  :class="
                    settings.sync_full_history
                      ? 'text-green-600'
                      : 'text-gray-500'
                  "
                >
                  {{
                    settings.sync_full_history
                      ? $t('GENERAL.YES')
                      : $t('GENERAL.NO')
                  }}
                </span>
              </div>
            </div>
          </div>
        </div>

        <form class="space-y-6" @submit.prevent="updateSettings">
          <!-- Reject Calls -->
          <div class="flex items-center justify-between">
            <div>
              <label class="text-sm font-medium">
                {{ $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.REJECT_CALL') }}
              </label>
              <p class="text-xs text-gray-500">
                {{ $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.REJECT_CALL_DESC') }}
              </p>
            </div>
            <WootSwitch v-model="settings.reject_call" />
          </div>

          <!-- Call Message -->
          <div v-if="settings.reject_call">
            <label class="text-sm font-medium">
              {{ $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.MSG_CALL') }}
            </label>
            <textarea
              v-model="settings.msg_call"
              class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
              rows="3"
              :placeholder="
                $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.MSG_CALL_PLACEHOLDER')
              "
            />
          </div>

          <!-- Other Settings -->
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <div>
                <label class="text-sm font-medium">
                  {{ $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.GROUPS_IGNORE') }}
                </label>
                <p class="text-xs text-gray-500">
                  {{ $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.GROUPS_IGNORE_DESC') }}
                </p>
              </div>
              <WootSwitch v-model="settings.groups_ignore" />
            </div>

            <div class="flex items-center justify-between">
              <div>
                <label class="text-sm font-medium">
                  {{ $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.ALWAYS_ONLINE') }}
                </label>
                <p class="text-xs text-gray-500">
                  {{ $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.ALWAYS_ONLINE_DESC') }}
                </p>
              </div>
              <WootSwitch v-model="settings.always_online" />
            </div>

            <div class="flex items-center justify-between">
              <div>
                <label class="text-sm font-medium">
                  {{ $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.READ_MESSAGES') }}
                </label>
                <p class="text-xs text-gray-500">
                  {{ $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.READ_MESSAGES_DESC') }}
                </p>
              </div>
              <WootSwitch v-model="settings.read_messages" />
            </div>

            <div class="flex items-center justify-between">
              <div>
                <label class="text-sm font-medium">
                  {{ $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.READ_STATUS') }}
                </label>
                <p class="text-xs text-gray-500">
                  {{ $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.READ_STATUS_DESC') }}
                </p>
              </div>
              <WootSwitch v-model="settings.read_status" />
            </div>

            <div class="flex items-center justify-between">
              <div>
                <label class="text-sm font-medium">
                  {{ $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.SYNC_FULL_HISTORY') }}
                </label>
                <p class="text-xs text-gray-500">
                  {{
                    $t('INBOX_MGMT.WHATSAPP_QR.SETTINGS.SYNC_FULL_HISTORY_DESC')
                  }}
                </p>
              </div>
              <WootSwitch v-model="settings.sync_full_history" />
            </div>
          </div>

          <!-- Save Button -->
          <div class="pt-4">
            <NextButton type="submit" :is-loading="isSavingSettings">
              {{ $t('INBOX_MGMT.WHATSAPP_QR.SAVE_SETTINGS') }}
            </NextButton>
          </div>
        </form>
      </SettingsSection>
    </div>

    <!-- Phone Number Modal - Temporarily disabled (API not working) -->
    <!--
    <woot-modal
      v-model:show="showPhoneModal"
      :on-close="() => { showPhoneModal = false; }"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">
          {{ $t('INBOX_MGMT.WHATSAPP_QR.PHONE_MODAL.TITLE') }}
        </h3>
        <form @submit.prevent="connectWithPhoneNumber">
          <div class="mb-4">
            <label class="block text-sm font-medium mb-2">
              {{ $t('INBOX_MGMT.WHATSAPP_QR.PHONE_MODAL.PHONE_LABEL') }}
            </label>
            <input
              v-model="phoneNumber"
              type="tel"
              class="w-full border border-gray-300 rounded-md px-3 py-2"
              :placeholder="$t('INBOX_MGMT.WHATSAPP_QR.PHONE_MODAL.PHONE_PLACEHOLDER')"
              required
            />
            <p class="text-xs text-gray-500 mt-1">
              {{ $t('INBOX_MGMT.WHATSAPP_QR.PHONE_MODAL.PHONE_HELP') }}
            </p>
          </div>
          <div class="flex justify-end space-x-3">
            <NextButton
              variant="hollow"
              @click="showPhoneModal = false"
            >
              {{ $t('INBOX_MGMT.WHATSAPP_QR.PHONE_MODAL.CANCEL') }}
            </NextButton>
            <NextButton
              type="submit"
              :is-loading="isConnectingPhone"
            >
              {{ $t('INBOX_MGMT.WHATSAPP_QR.PHONE_MODAL.CONNECT') }}
            </NextButton>
          </div>
        </form>
      </div>
    </woot-modal>
    -->
  </div>
</template>
