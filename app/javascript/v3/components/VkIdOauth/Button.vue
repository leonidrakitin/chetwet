<script setup>
import { onMounted, onBeforeUnmount, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
const containerRef = ref(null);
let oneTapInstance = null;

function loadVkIdSdk() {
  return new Promise((resolve, reject) => {
    if (window.VKIDSDK) {
      resolve(window.VKIDSDK);
      return;
    }
    const script = document.createElement('script');
    script.src = 'https://unpkg.com/@vkid/sdk@<3.0.0/dist-sdk/umd/index.js';
    script.onload = () => resolve(window.VKIDSDK);
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

async function handleVkSuccess(data) {
  try {
    const response = await fetch('/api/v1/auth/vk_sdk_callback', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ access_token: data.access_token }),
    });
    const result = await response.json();
    if (result.sso_auth_token) {
      let url = `/app/login?email=${encodeURIComponent(result.email)}&sso_auth_token=${result.sso_auth_token}`;
      if (result.redirect) {
        url += `&redirect=${encodeURIComponent(result.redirect)}`;
      }
      window.location = url;
    } else {
      useAlert(t('LOGIN.OAUTH.NO_ACCOUNT_FOUND'));
    }
  } catch {
    useAlert(t('LOGIN.API.UNAUTH'));
  }
}

onMounted(async () => {
  try {
    const VKID = await loadVkIdSdk();

    VKID.Config.init({
      app: parseInt(window.chatwootConfig.vkIdClientId, 10),
      redirectUrl: window.chatwootConfig.vkIdCallbackUrl,
      responseMode: VKID.ConfigResponseMode.Callback,
      source: VKID.ConfigSource.LOWCODE,
      scope: 'email',
    });

    oneTapInstance = new VKID.OneTap();
    oneTapInstance
      .render({
        container: containerRef.value,
        showAlternativeLogin: true,
        oauthList: ['mail_ru', 'ok_ru'],
      })
      .on(VKID.WidgetEvents.ERROR, () => {
        useAlert(t('LOGIN.API.UNAUTH'));
      })
      .on(VKID.OneTapInternalEvents.LOGIN_SUCCESS, payload => {
        VKID.Auth.exchangeCode(payload.code, payload.device_id)
          .then(handleVkSuccess)
          .catch(() => useAlert(t('LOGIN.API.UNAUTH')));
      });
  } catch {
    // SDK failed to load, fall back silently
  }
});

onBeforeUnmount(() => {
  if (oneTapInstance) {
    oneTapInstance.close();
  }
});
</script>

<template>
  <div ref="containerRef" />
</template>
