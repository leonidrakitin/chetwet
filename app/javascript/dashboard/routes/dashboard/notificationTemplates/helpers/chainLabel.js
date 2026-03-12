/**
 * Shared chain/template label for notification templates.
 * Used by FlowMap and TemplateCard for consistent "chain" display.
 * @param {Object} template - template object with type, triggerEvent, timeOffset, etc.
 * @param {Function} t - i18n t function
 * @returns {string}
 */
export function getChainLabel(template, t) {
  if (!template) return '';
  if (template.type === 'event' && template.triggerEvent) {
    return t(
      `NOTIFICATION_TEMPLATES.EVENTS.${String(template.triggerEvent).toUpperCase()}`
    );
  }
  if (template.type === 'time') {
    return template.schedule?.send_at || t('NOTIFICATION_TEMPLATES.TYPES.TIME');
  }
  if (template.type === 'interval') {
    const intervalDays = template.conditions?.interval_days ?? '';
    const since = (template.conditions?.since || 'last_message').toUpperCase();
    return `${intervalDays}d · ${t(`NOTIFICATION_TEMPLATES.SINCE.${since}`)}`;
  }
  const key = (template.type || '').toUpperCase().replace(/-/g, '_');
  return key ? t(`NOTIFICATION_TEMPLATES.TYPES.${key}`) : '';
}

export const FLOW_TYPE_ORDER = ['event', 'time', 'interval'];
