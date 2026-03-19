<script>
export default {
  methods: {
    getVkAuthUrl() {
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
      :href="getVkAuthUrl()"
      class="inline-flex justify-center w-full px-4 py-3 bg-n-background dark:bg-n-solid-3 items-center rounded-xl shadow-sm ring-1 ring-inset ring-n-container dark:ring-n-container focus:outline-offset-0 hover:bg-n-alpha-2 dark:hover:bg-n-alpha-2 transition-colors"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill="none"
      >
        <path
          d="M12.77 17.29c-5.47 0-8.59-3.74-8.72-9.96h2.74c.09 4.56 2.1 6.49 3.69 6.89V7.33h2.58v3.93c1.57-.17 3.22-1.97 3.78-3.93h2.58c-.43 2.41-2.22 4.21-3.5 4.95 1.28.6 3.31 2.17 4.09 5.01h-2.84c-.61-1.9-2.13-3.37-4.11-3.57v3.57h-.29z"
          fill="#0077FF"
        />
      </svg>
      <span class="ml-2 text-base font-medium text-n-slate-12">
        {{ $t('LOGIN.OAUTH.VK_ID_LOGIN') }}
      </span>
    </a>
  </div>
</template>
