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
    return t(`NOTIFICATION_TEMPLATES.EVENTS.${template.triggerEvent}`);
  }
  if (template.type === 'time') {
    const offset = template.timeOffset ?? '';
    const unit = t(
      `NOTIFICATION_TEMPLATES.TIME_UNIT.${template.timeUnit ?? 'HOURS'}`
    );
    const dir = t(
      `NOTIFICATION_TEMPLATES.TIME_DIRECTION.${template.timeDirection ?? 'BEFORE'}`
    );
    return `${offset} ${unit} ${dir}`;
  }
  const key = (template.type || '').toUpperCase().replace(/-/g, '_');
  return key ? t(`NOTIFICATION_TEMPLATES.TYPES.${key}`) : '';
}

export const FLOW_TYPE_ORDER = [
  'event',
  'time',
  'lost_clients',
  'client_consent',
];
