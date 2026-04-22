const PUNCTUATION = /[\s().\-_]/g;

export const MIN_SEARCH_LENGTH = 2;

/**
 * Normalizes a contact search query so the backend can match with ILIKE '%input%'.
 *
 * Phone-like input (digits with optional +, spaces, parens, dashes) is reduced
 * to digits only; Russian 11-digit numbers starting with 7 or 8 drop the country
 * prefix so `%9819723429%` matches phones stored as `+7...`, `8...` or raw digits.
 *
 * Non-numeric input is kept as the trimmed string for substring name/email match.
 */
export const normalizeContactSearchQuery = raw => {
  if (!raw) return '';
  const trimmed = raw.trim();
  if (!trimmed) return '';

  const compact = trimmed.replace(PUNCTUATION, '');
  if (!/^\+?\d+$/.test(compact)) return trimmed;

  let digits = compact.replace(/\D/g, '');
  // Strip a leading Russian country/city prefix (7 or 8) so "+7…", "8…" and
  // the bare subscriber number all land on the same substring in the backend.
  // Keep the prefix when removing it would leave too little to disambiguate.
  if (
    digits.length >= 3 &&
    (digits.startsWith('7') || digits.startsWith('8'))
  ) {
    digits = digits.slice(1);
  }
  return digits;
};

export const isPhoneLikeQuery = raw => {
  if (!raw) return false;
  const compact = raw.trim().replace(PUNCTUATION, '');
  return /^\+?\d+$/.test(compact);
};
