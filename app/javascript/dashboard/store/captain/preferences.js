import { defineStore } from 'pinia';
import CaptainPreferencesAPI from 'dashboard/api/captain/preferences';

export const useCaptainConfigStore = defineStore('captainConfig', {
  state: () => ({
    providers: {},
    models: {},
    features: {},
    enabledProviders: [],
    primaryProvider: 'openai',
    messageBufferSeconds: 4,
    uiFlags: {
      isFetching: false,
    },
  }),

  getters: {
    getProviders: state => state.providers,
    getModels: state => state.models,
    getFeatures: state => state.features,
    getUIFlags: state => state.uiFlags,
    getEnabledProviders: state => state.enabledProviders,
    getPrimaryProvider: state => state.primaryProvider,
    getModelsForFeature: state => featureKey => {
      const feature = state.features[featureKey];
      const models = feature?.models || [];

      const providerOrder = {
        openai: 0,
        anthropic: 1,
        zai: 2,
        deepseek: 3,
        qwen: 4,
        gemini: 5,
      };

      return [...models].sort((a, b) => {
        if (a.coming_soon && !b.coming_soon) return 1;
        if (!a.coming_soon && b.coming_soon) return -1;

        const providerA = providerOrder[a.provider] ?? 999;
        const providerB = providerOrder[b.provider] ?? 999;
        if (providerA !== providerB) return providerA - providerB;

        return (b.credit_multiplier || 0) - (a.credit_multiplier || 0);
      });
    },
    getDefaultModelForFeature: state => featureKey => {
      const feature = state.features[featureKey];
      return feature?.default || null;
    },
    getSelectedModelForFeature: state => featureKey => {
      const feature = state.features[featureKey];
      return feature?.selected || feature?.default || null;
    },
  },

  actions: {
    async fetch() {
      this.uiFlags.isFetching = true;
      try {
        const response = await CaptainPreferencesAPI.get();
        this.providers = response.data.providers || {};
        this.models = response.data.models || {};
        this.features = response.data.features || {};
        this.enabledProviders = response.data.enabled_providers || [];
        this.primaryProvider = response.data.primary_provider || 'openai';
        const sec = response.data.message_buffer_seconds;
        this.messageBufferSeconds =
          typeof sec === 'number' && sec >= 1 && sec <= 30 ? sec : 4;
      } catch (error) {
        // Ignore error
      } finally {
        this.uiFlags.isFetching = false;
      }
    },

    async updatePreferences(data) {
      const response = await CaptainPreferencesAPI.updatePreferences(data);
      this.providers = response.data.providers || {};
      this.models = response.data.models || {};
      this.features = response.data.features || {};
      this.enabledProviders = response.data.enabled_providers || [];
      this.primaryProvider = response.data.primary_provider || 'openai';
      const sec = response.data.message_buffer_seconds;
      if (typeof sec === 'number' && sec >= 1 && sec <= 30) {
        this.messageBufferSeconds = sec;
      }
    },
  },
});
