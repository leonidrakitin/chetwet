export const BUILTIN_CATEGORIES = [
  {
    key: 'system',
    icon: 'i-lucide-shield-check',
    color: 'text-n-blue-11',
    bgColor: 'bg-n-blue-3',
    templates: [
      {
        id: 'sys-welcome',
        builtinKey: 'WELCOME_MESSAGE',
        icon: 'i-lucide-hand-metal',
      },
      {
        id: 'sys-update-profile',
        builtinKey: 'UPDATE_PROFILE',
        icon: 'i-lucide-user-pen',
      },
      {
        id: 'sys-verify-email',
        builtinKey: 'VERIFY_EMAIL',
        icon: 'i-lucide-mail-check',
      },
      {
        id: 'sys-password-reset',
        builtinKey: 'PASSWORD_RESET',
        icon: 'i-lucide-key-round',
      },
      {
        id: 'sys-feedback-request',
        builtinKey: 'FEEDBACK_REQUEST',
        icon: 'i-lucide-message-square-heart',
      },
    ],
  },
  {
    key: 'yclients',
    icon: 'i-lucide-calendar-check',
    color: 'text-n-teal-11',
    bgColor: 'bg-n-teal-3',
    templates: [
      {
        id: 'yc-booking-reminder',
        builtinKey: 'BOOKING_REMINDER',
        icon: 'i-lucide-bell-ring',
      },
      {
        id: 'yc-record-update',
        builtinKey: 'RECORD_UPDATE',
        icon: 'i-lucide-clipboard-edit',
      },
      {
        id: 'yc-lookup-result',
        builtinKey: 'LOOKUP_RESULT',
        icon: 'i-lucide-search-check',
      },
      {
        id: 'yc-visit-followup',
        builtinKey: 'VISIT_FOLLOWUP',
        icon: 'i-lucide-heart-handshake',
      },
      {
        id: 'yc-cancel-confirm',
        builtinKey: 'CANCEL_CONFIRM',
        icon: 'i-lucide-calendar-x',
      },
    ],
  },
  {
    key: 'yours',
    icon: 'i-lucide-sparkles',
    color: 'text-n-violet-11',
    bgColor: 'bg-n-violet-3',
    templates: [],
  },
];
