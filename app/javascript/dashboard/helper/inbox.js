export const INBOX_TYPES = {
  WEB: 'Channel::WebWidget',
  FB: 'Channel::FacebookPage',
  TWITTER: 'Channel::TwitterProfile',
  TWILIO: 'Channel::TwilioSms',
  WHATSAPP: 'Channel::Whatsapp',
  API: 'Channel::Api',
  EMAIL: 'Channel::Email',
  TELEGRAM: 'Channel::Telegram',
  TELEGRAM_PERSONAL: 'Channel::TelegramPersonal',
  VK: 'Channel::Vk',
  AVITO: 'Channel::Avito',
  MAX: 'Channel::Max',
  LINE: 'Channel::Line',
  SMS: 'Channel::Sms',
  INSTAGRAM: 'Channel::Instagram',
  TIKTOK: 'Channel::Tiktok',
  VOICE: 'Channel::Voice',
};

export const TWILIO_CHANNEL_MEDIUM = {
  WHATSAPP: 'whatsapp',
  SMS: 'sms',
};

const INBOX_ICON_MAP_FILL = {
  [INBOX_TYPES.WEB]: 'i-ri-global-fill',
  [INBOX_TYPES.FB]: 'i-ri-messenger-fill',
  [INBOX_TYPES.TWITTER]: 'i-ri-twitter-x-fill',
  [INBOX_TYPES.WHATSAPP]: 'i-ri-whatsapp-fill',
  [INBOX_TYPES.API]: 'i-ri-cloudy-fill',
  [INBOX_TYPES.EMAIL]: 'i-ri-mail-fill',
  [INBOX_TYPES.TELEGRAM]: 'i-ri-telegram-fill',
  [INBOX_TYPES.TELEGRAM_PERSONAL]: 'i-ri-telegram-fill',
  [INBOX_TYPES.VK]: 'i-woot-vk',
  [INBOX_TYPES.AVITO]: 'i-woot-avito',
  [INBOX_TYPES.MAX]: 'i-woot-max',
  [INBOX_TYPES.LINE]: 'i-ri-line-fill',
  [INBOX_TYPES.INSTAGRAM]: 'i-ri-instagram-fill',
  [INBOX_TYPES.TIKTOK]: 'i-ri-tiktok-fill',
  [INBOX_TYPES.VOICE]: 'i-ri-phone-fill',
};

const DEFAULT_ICON_FILL = 'i-ri-chat-1-fill';

const INBOX_ICON_MAP_LINE = {
  [INBOX_TYPES.WEB]: 'i-woot-website',
  [INBOX_TYPES.FB]: 'i-woot-messenger',
  [INBOX_TYPES.TWITTER]: 'i-woot-x',
  [INBOX_TYPES.WHATSAPP]: 'i-woot-whatsapp',
  [INBOX_TYPES.API]: 'i-woot-api',
  [INBOX_TYPES.EMAIL]: 'i-woot-mail',
  [INBOX_TYPES.TELEGRAM]: 'i-woot-telegram',
  [INBOX_TYPES.TELEGRAM_PERSONAL]: 'i-woot-telegram',
  [INBOX_TYPES.VK]: 'i-woot-vk',
  [INBOX_TYPES.AVITO]: 'i-woot-avito',
  [INBOX_TYPES.MAX]: 'i-woot-max',
  [INBOX_TYPES.LINE]: 'i-woot-line',
  [INBOX_TYPES.INSTAGRAM]: 'i-woot-instagram',
  [INBOX_TYPES.VOICE]: 'i-woot-voice',
  [INBOX_TYPES.TIKTOK]: 'i-woot-tiktok',
};

const DEFAULT_ICON_LINE = 'i-ri-chat-1-line';

export const getInboxSource = (type, phoneNumber, inbox) => {
  switch (type) {
    case INBOX_TYPES.WEB:
      return inbox.website_url || '';

    case INBOX_TYPES.TWILIO:
    case INBOX_TYPES.WHATSAPP:
    case INBOX_TYPES.VOICE:
    case INBOX_TYPES.TELEGRAM_PERSONAL:
      return phoneNumber || '';

    case INBOX_TYPES.EMAIL:
      return inbox.email || '';

    default:
      return '';
  }
};
export const getReadableInboxByType = (type, phoneNumber) => {
  switch (type) {
    case INBOX_TYPES.WEB:
      return 'livechat';

    case INBOX_TYPES.FB:
      return 'facebook';

    case INBOX_TYPES.TWITTER:
      return 'twitter';

    case INBOX_TYPES.TWILIO:
      return phoneNumber?.startsWith('whatsapp') ? 'whatsapp' : 'sms';

    case INBOX_TYPES.WHATSAPP:
      return 'whatsapp';

    case INBOX_TYPES.API:
      return 'api';

    case INBOX_TYPES.EMAIL:
      return 'email';

    case INBOX_TYPES.TELEGRAM:
      return 'telegram';

    case INBOX_TYPES.TELEGRAM_PERSONAL:
      return 'telegram';

    case INBOX_TYPES.VK:
      return 'vk';

    case INBOX_TYPES.AVITO:
      return 'avito';

    case INBOX_TYPES.MAX:
      return 'max';

    case INBOX_TYPES.LINE:
      return 'line';

    case INBOX_TYPES.VOICE:
      return 'voice';

    default:
      return 'chat';
  }
};

export const getInboxClassByType = (type, phoneNumber) => {
  switch (type) {
    case INBOX_TYPES.WEB:
      return 'globe-desktop';

    case INBOX_TYPES.FB:
      return 'brand-facebook';

    case INBOX_TYPES.TWITTER:
      return 'brand-twitter';

    case INBOX_TYPES.TWILIO:
      return phoneNumber?.startsWith('whatsapp')
        ? 'brand-whatsapp'
        : 'brand-sms';

    case INBOX_TYPES.WHATSAPP:
      return 'brand-whatsapp';

    case INBOX_TYPES.API:
      return 'cloud';

    case INBOX_TYPES.EMAIL:
      return 'mail';

    case INBOX_TYPES.TELEGRAM:
      return 'brand-telegram';

    case INBOX_TYPES.TELEGRAM_PERSONAL:
      return 'brand-telegram';

    case INBOX_TYPES.VK:
      return 'vk';

    case INBOX_TYPES.AVITO:
      return 'avito';

    case INBOX_TYPES.MAX:
      return 'max';

    case INBOX_TYPES.LINE:
      return 'brand-line';

    case INBOX_TYPES.INSTAGRAM:
      return 'brand-instagram';

    case INBOX_TYPES.TIKTOK:
      return 'brand-tiktok';

    case INBOX_TYPES.VOICE:
      return 'phone';

    default:
      return 'chat';
  }
};

export const getInboxIconByType = (type, medium, variant = 'fill') => {
  const iconMap =
    variant === 'fill' ? INBOX_ICON_MAP_FILL : INBOX_ICON_MAP_LINE;
  const defaultIcon =
    variant === 'fill' ? DEFAULT_ICON_FILL : DEFAULT_ICON_LINE;

  // Special case for Twilio (whatsapp and sms)
  if (type === INBOX_TYPES.TWILIO && medium === 'whatsapp') {
    return iconMap[INBOX_TYPES.WHATSAPP];
  }

  return iconMap[type] ?? defaultIcon;
};

export const getInboxWarningIconClass = (type, reauthorizationRequired) => {
  const allowedInboxTypes = [INBOX_TYPES.FB, INBOX_TYPES.EMAIL];
  if (allowedInboxTypes.includes(type) && reauthorizationRequired) {
    return 'warning';
  }
  return '';
};

/** Brand / channel colors for small inbox badge on avatars (readable in light & dark UI chrome) */
export const INBOX_BADGE_BACKGROUND_COLORS = {
  [INBOX_TYPES.FB]: '#0084FF',
  [INBOX_TYPES.TWITTER]: '#000000',
  [INBOX_TYPES.WHATSAPP]: '#25D366',
  [INBOX_TYPES.TWILIO]: '#F22F46',
  [INBOX_TYPES.API]: '#6366F1',
  [INBOX_TYPES.EMAIL]: '#8B5CF6',
  [INBOX_TYPES.TELEGRAM]: '#229ED9',
  [INBOX_TYPES.TELEGRAM_PERSONAL]: '#229ED9',
  [INBOX_TYPES.VK]: '#0077FF',
  [INBOX_TYPES.AVITO]: '#97CF26',
  [INBOX_TYPES.MAX]: '#6B4EE2',
  [INBOX_TYPES.LINE]: '#06C755',
  [INBOX_TYPES.SMS]: '#57534E',
  [INBOX_TYPES.INSTAGRAM]: '#E4405F',
  [INBOX_TYPES.TIKTOK]: '#000000',
  [INBOX_TYPES.VOICE]: '#0D9488',
  [INBOX_TYPES.WEB]: '#5B7CFF',
};

function parseHexColorRgb(hex) {
  if (!hex || typeof hex !== 'string') return null;
  let h = hex.trim();
  if (h.startsWith('#')) h = h.slice(1);
  if (h.length === 3) {
    return [
      parseInt(h[0] + h[0], 16),
      parseInt(h[1] + h[1], 16),
      parseInt(h[2] + h[2], 16),
    ];
  }
  if (h.length === 6) {
    const r = Number.parseInt(h.slice(0, 2), 16);
    const g = Number.parseInt(h.slice(2, 4), 16);
    const b = Number.parseInt(h.slice(4, 6), 16);
    if ([r, g, b].some(c => Number.isNaN(c))) return null;
    return [r, g, b];
  }
  return null;
}

function hexRelativeLuminance(hex) {
  const rgb = parseHexColorRgb(hex);
  if (!rgb) return 0;

  const lin = channel => {
    const c = channel / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  };
  const [r, g, b] = rgb.map(lin);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/**
 * Prefer dark foreground on very light inbox widget colors so the glyph stays visible.
 */
export function inboxBadgeUsesDarkIcon(backgroundHex) {
  return hexRelativeLuminance(backgroundHex) > 0.62;
}

function resolveBadgeChannelKey(inbox) {
  const channelType = inbox.channel_type || inbox.channelType;
  const medium = inbox.medium;
  let phoneNumber = '';
  if (typeof inbox.phone_number === 'string') {
    phoneNumber = inbox.phone_number;
  } else if (typeof inbox.phoneNumber === 'string') {
    phoneNumber = inbox.phoneNumber;
  }

  if (!channelType) return null;

  if (channelType === INBOX_TYPES.TWILIO) {
    if (
      medium === TWILIO_CHANNEL_MEDIUM.WHATSAPP ||
      phoneNumber.toLowerCase().startsWith('whatsapp')
    ) {
      return INBOX_TYPES.WHATSAPP;
    }
    return INBOX_TYPES.TWILIO;
  }

  return channelType;
}

/**
 * @returns {{ backgroundColor: string | null, iconClass: string, useNeutralChrome: boolean }}
 */
export function getInboxBadgePresentation(inbox) {
  if (!inbox) {
    return {
      backgroundColor: null,
      iconClass: 'text-n-text-body',
      useNeutralChrome: true,
    };
  }

  const channelTypeRaw = inbox.channel_type || inbox.channelType;
  const channelKey = resolveBadgeChannelKey(inbox);
  const widgetColorRaw = inbox.widget_color ?? inbox.widgetColor;

  let background = null;
  if (
    channelTypeRaw === INBOX_TYPES.WEB &&
    widgetColorRaw &&
    parseHexColorRgb(widgetColorRaw)
  ) {
    background = widgetColorRaw;
  }

  if (!background && channelKey) {
    background = INBOX_BADGE_BACKGROUND_COLORS[channelKey] ?? null;
  }

  if (!background) {
    return {
      backgroundColor: null,
      iconClass: 'text-n-text-body',
      useNeutralChrome: true,
    };
  }

  const darkIcon = inboxBadgeUsesDarkIcon(background);

  return {
    backgroundColor: background,
    iconClass: darkIcon ? 'text-n-text-display' : 'text-white',
    useNeutralChrome: false,
  };
}
