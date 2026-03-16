<script>
export default {
  methods: {
    getYandexAuthUrl() {
      const baseUrl = 'https://oauth.yandex.ru/authorize';
      const clientId = window.chatwootConfig.yandexOAuthClientId;
      const redirectUri = window.chatwootConfig.yandexOAuthCallbackUrl;

      const queryString = new URLSearchParams({
        client_id: clientId,
        redirect_uri: redirectUri,
        response_type: 'code',
        scope: 'login:email login:info login:avatar',
      }).toString();

      return `${baseUrl}?${queryString}`;
    },
  },
};
</script>

<template>
  <div class="flex flex-col">
    <a
      :href="getYandexAuthUrl()"
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
          d="M13.32 7.666h-.924c-1.694 0-2.585.858-2.585 2.123 0 1.43.616 2.09 1.881 2.948l1.045.704-3.003 4.487H7.49l2.695-4.014c-1.55-1.111-2.42-2.19-2.42-4.015 0-2.288 1.595-3.85 4.63-3.85h3.003v11.88h-2.08V7.665z"
          fill="currentColor"
        />
      </svg>
      <span class="ml-2 text-base font-medium text-n-slate-12">
        {{ $t('LOGIN.OAUTH.YANDEX_LOGIN') }}
      </span>
    </a>
  </div>
</template>
