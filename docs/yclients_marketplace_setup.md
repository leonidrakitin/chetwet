# YClients Marketplace integration setup

This document describes how to configure the YClients Marketplace integration (iframe registration and callback activation) in the YClients developer dashboard and in Chatwoot.

## Prerequisites

- Chatwoot instance with a public URL (e.g. `https://your-chatwoot.example.com`).
- An application registered in the [YClients developer cabinet](https://yclients.com/).

## 1. Chatwoot configuration

### Installation config (Super Admin or database)

Set the following in Installation Config (Super Admin → Configuration, or `config/installation_config.yml` and run config loader):

| Name | Description |
|------|-------------|
| `YCLIENTS_MARKETPLACE_PARTNER_TOKEN` | Partner token for YClients Marketplace API (from your app settings in YClients). Used for callback and auth. |
| `YCLIENTS_SYSTEM_USER_ID` | System User ID from your YClients app settings. Passed in `callback_with_settings` as `settings.user_id`. |
| `YCLIENTS_MARKETPLACE_APPLICATION_ID` | Marketplace application ID from YClients. Used for payment and refund callbacks. |

Optional for webhook signature verification:

| Name | Description |
|------|-------------|
| `YCLIENTS_MARKETPLACE_WEBHOOK_SECRET` | Secret used to verify webhook requests (e.g. `X-Yclients-Signature` or `X-Webhook-Signature` header). |

## 2. YClients developer cabinet settings

In the YClients developer dashboard, edit your application and open **“Настройки для разработки”** (Development settings).

### Registration Redirect URL

- Set **Registration Redirect URL** to:
  ```text
  https://<YOUR_FRONTEND_URL>/app/yclients/connect
  ```
  Example: `https://chatwoot.example.com/app/yclients/connect` (no trailing slash).
- This URL is opened in the iframe when the user clicks “Подключить” in the Marketplace.

### Checkboxes

1. **«Открывать форму регистрации в iframe»** (Open registration form in iframe) — **enabled**.  
   So the connect page is shown inside the YClients tab instead of a redirect.

2. **«Разрешить добавление в несколько филиалов»** (Allow adding to multiple branches) — **enabled** if you want to support multiple `salon_id`s per user.  
   When enabled, YClients may send `salon_ids[]` instead of a single `salon_id`.

3. (Optional) **«Передавать данные пользователя при подключении»** (Pass user data on connect) — when enabled, YClients adds `user_data` and `user_data_sign` to the redirect URL. Handling these for pre-filling the form is planned for a later phase.

### System User ID

- In the app settings, find **System User ID** (or the field that identifies the system user for the Marketplace API).
- Put the same value into Chatwoot’s `YCLIENTS_SYSTEM_USER_ID` config (see above).

### Documentation for your app

- In the developer cabinet, open **«Документация для вашего приложения»** (Documentation for your application).
- Confirm the **exact callback URL** (v1 vs v2), e.g.:
  - `https://api.yclients.com/api/v2/marketplace/notifications/callback_with_settings`
  - or the v1 variant if specified there.
- Confirm the **webhook event names and payload** (e.g. `integration_revoked`, `integration_activated`) so you can adjust the webhook handler if needed.

## 3. Chatwoot endpoints used by the integration

| Purpose | Method | URL |
|--------|--------|-----|
| Connect page (iframe) | GET | `https://<FRONTEND_URL>/app/yclients/connect?salon_id=...` or `?salon_ids[]=...` |
| Start Marketplace activation | POST | `https://<FRONTEND_URL>/api/v1/accounts/:account_id/integrations/yclients_marketplace/connect` (body: `{ "salon_ids": [123, 456] }`) |
| Notify YClients about successful partner billing | POST | `https://<FRONTEND_URL>/api/v1/accounts/:account_id/integrations/yclients_marketplace/payment` |
| Notify YClients about a payment refund | POST | `https://<FRONTEND_URL>/api/v1/accounts/:account_id/integrations/yclients_marketplace/payment/refund/:payment_id` |
| YClients Marketplace webhooks | POST | `https://<FRONTEND_URL>/webhooks/yclients/marketplace` |

Configure the webhook URL in YClients (if required) to point to `https://<FRONTEND_URL>/webhooks/yclients/marketplace`.

## 4. Flow summary

1. User clicks “Подключить” in YClients Marketplace → YClients opens `Registration Redirect URL` in an iframe with `salon_id` (or `salon_ids[]`) in the query.
2. User logs in (if needed) and selects an account, then clicks “Connect” on the connect page.
3. Chatwoot enqueues a job that calls YClients `callback_with_settings` and then obtains/stores the bearer token (or waits for the `integration_activated` webhook).
4. A record is created/updated in `yclients_integrations` and an `Integrations::Hook` is created/updated so existing YClients CRM logic works.
5. When YClients sends `integration_revoked` (or similar), Chatwoot marks the integration as revoked and disables the matching `Integrations::Hook`. When it sends `integration_activated` with a token, Chatwoot restores the stored bearer token and enables the hook again.
6. If your marketplace moderation requires partner billing callbacks, call the payment and refund endpoints above from your billing flow so Chatwoot can relay them to YClients with the configured partner token and application ID.

## 5. Screenshots (recommended)

When documenting for your team, add screenshots of:

- The **Registration Redirect URL** field in the YClients app settings.
- The **«Открывать форму регистрации в iframe»** and **«Разрешить добавление в несколько филиалов»** checkboxes.
- Where **System User ID** is shown in the YClients developer cabinet.
- The **«Документация для вашего приложения»** section with the callback URL and webhook format.
