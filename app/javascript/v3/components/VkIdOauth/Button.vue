<script>
export default {
  methods: {
    getVkIdAuthUrl() {
      const baseUrl = 'https://id.vk.com/authorize';
      const clientId = window.chatwootConfig.vkIdClientId;
      const redirectUri = window.chatwootConfig.vkIdCallbackUrl;

      const queryString = new URLSearchParams({
        client_id: clientId,
        redirect_uri: redirectUri,
        response_type: 'code',
        scope: 'email',
      }).toString();

      return `${baseUrl}?${queryString}`;
    },
  },
};
</script>

<template>
  <div class="flex flex-col">
    <a
      :href="getVkIdAuthUrl()"
      class="inline-flex justify-center w-full px-4 py-3 bg-n-background dark:bg-n-solid-3 items-center rounded-md shadow-sm ring-1 ring-inset ring-n-container dark:ring-n-container focus:outline-offset-0 hover:bg-n-alpha-2 dark:hover:bg-n-alpha-2"
    >
      <span class="text-base font-bold text-[#0077FF]">
        {{ $t('LOGIN.OAUTH.VK') }}
      </span>
      <span class="ml-2 text-base font-medium text-n-slate-12">
        {{ $t('LOGIN.OAUTH.VK_ID_LOGIN') }}
      </span>
    </a>
  </div>
</template>
