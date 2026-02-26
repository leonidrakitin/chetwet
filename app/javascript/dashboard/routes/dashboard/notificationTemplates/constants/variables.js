/**
 * Shared variable definitions for notification templates.
 * Used by VariablePicker and TemplateMessageEditor.
 * Labels, descriptions and examples come from i18n: NOTIFICATION_TEMPLATES.VARIABLES.<key>, .<key>_description, .<key>_example
 */
export const VARIABLE_KEYS = [
  'client_name',
  'service_name',
  'branch_name',
  'master_name',
  'price',
  'date',
  'time',
];

export const VARIABLE_COLORS = {
  client_name: { bg: '#dbeafe', text: '#1d4ed8', border: '#bfdbfe' },
  service_name: { bg: '#ccfbf1', text: '#0f766e', border: '#99f6e4' },
  branch_name: { bg: '#fef3c7', text: '#b45309', border: '#fde68a' },
  master_name: { bg: '#ede9fe', text: '#7c3aed', border: '#ddd6fe' },
  price: { bg: '#fee2e2', text: '#b91c1c', border: '#fecaca' },
  date: { bg: '#ffedd5', text: '#c2410c', border: '#fed7aa' },
  time: { bg: '#e2e8f0', text: '#334155', border: '#cbd5e1' },
};

export const VARIABLE_CATEGORIES = [
  { key: 'client', variables: ['client_name'] },
  {
    key: 'appointment',
    variables: ['service_name', 'branch_name', 'master_name'],
  },
  { key: 'payment', variables: ['price'] },
  { key: 'datetime', variables: ['date', 'time'] },
];

export const toToken = key => `{${key}}`;

export const parseMessageParts = text => {
  if (!text || typeof text !== 'string') return [];
  const parts = [];
  const regex = /\{(\w+)\}/g;
  let lastIndex = 0;
  let match = regex.exec(text);
  while (match !== null) {
    if (match.index > lastIndex) {
      parts.push({ type: 'text', value: text.slice(lastIndex, match.index) });
    }
    parts.push({ type: 'variable', key: match[1], value: match[0] });
    lastIndex = match.index + match[0].length;
    match = regex.exec(text);
  }
  if (lastIndex < text.length) {
    parts.push({ type: 'text', value: text.slice(lastIndex) });
  }
  return parts;
};
