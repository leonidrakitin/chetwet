import { emitter } from 'shared/helpers/mitt';
import analyticsHelper from 'dashboard/helper/AnalyticsHelper/index';

/**
 * Custom hook to track events
 */
export const useTrack = (...args) => {
  try {
    return analyticsHelper.track(...args);
  } catch (error) {
    // Ignore this, tracking is not mission critical
  }

  return null;
};

/**
 * Emits a toast message event using a global emitter.
 * @param {string} message - The message to be displayed in the toast.
 * @param {Object|null} action - Optional action object. Supports `variant` ('success'|'error'|'warning'|'info').
 */
export const useAlert = (message, action = null) => {
  emitter.emit('newToastMessage', { message, action });
};

/**
 * Convenience helpers for typed toast notifications.
 */
export const useToast = {
  success: (message, action = null) =>
    useAlert(message, { ...action, variant: 'success' }),
  error: (message, action = null) =>
    useAlert(message, { ...action, variant: 'error' }),
  warning: (message, action = null) =>
    useAlert(message, { ...action, variant: 'warning' }),
  info: (message, action = null) =>
    useAlert(message, { ...action, variant: 'info' }),
};
