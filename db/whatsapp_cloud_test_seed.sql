-- Seed WhatsApp Cloud channel + inbox for testing.
--
-- Run (replace DB name if needed):
--   psql -d chatwoot_development -f db/whatsapp_cloud_test_seed.sql
--
-- Or from Rails console:
--   sql = File.read(Rails.root.join('db/whatsapp_cloud_test_seed.sql'))
--   ActiveRecord::Base.connection.execute(sql)
--
-- Before use: replace in provider_config:
--   YOUR_META_ACCESS_TOKEN  -> Meta WhatsApp Cloud API token
--   YOUR_PHONE_NUMBER_ID   -> Phone number ID from Meta
--   YOUR_WABA_ID           -> WhatsApp Business Account ID

-- 1) Insert WhatsApp Cloud channel (use first account if you don't set @account_id)
WITH first_account AS (
  SELECT id FROM accounts LIMIT 1
),
new_channel AS (
  INSERT INTO channel_whatsapp (
    account_id,
    phone_number,
    provider,
    provider_config,
    message_templates,
    created_at,
    updated_at
  )
  SELECT
    first_account.id,
    '15550001111',                    -- unique phone number (change if needed)
    'whatsapp_cloud',
    '{
      "api_key": "YOUR_META_ACCESS_TOKEN",
      "phone_number_id": "YOUR_PHONE_NUMBER_ID",
      "business_account_id": "YOUR_WABA_ID",
      "webhook_verify_token": "test_verify_token_123",
      "source": "embedded_signup"
    }'::jsonb,
    '{}'::jsonb,
    NOW(),
    NOW()
  FROM first_account
  RETURNING id, account_id
),
new_inbox AS (
  INSERT INTO inboxes (
    channel_id,
    channel_type,
    account_id,
    name,
    created_at,
    updated_at
  )
  SELECT
    new_channel.id,
    'Channel::Whatsapp',
    new_channel.account_id,
    'WhatsApp Cloud (Test)',
    NOW(),
    NOW()
  FROM new_channel
  RETURNING id, account_id
)
-- 3) Assign all account users to the new inbox (otherwise it won't appear in the UI)
INSERT INTO inbox_members (user_id, inbox_id, created_at, updated_at)
SELECT u.id, new_inbox.id, NOW(), NOW()
FROM new_inbox
JOIN users u ON u.account_id = new_inbox.account_id;

-- If the inbox was created manually and does not appear in the UI, assign users:
--   bundle exec rails inbox:assign_all[6]
-- or by name:  bundle exec rails inbox:assign_all["WhatsApp Cloud"]
-- Then hard-refresh the page (Ctrl+Shift+R) or log out and back in.
