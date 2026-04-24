import { differenceInMinutes } from 'date-fns';

export const SLOT_HEIGHT = 48;

const assignColumnsGreedy = events => {
  const sorted = [...events].sort((a, b) => {
    const diff = a.start - b.start;
    if (diff !== 0) return diff;
    return b.end - a.end;
  });

  const columnEnds = [];
  const withColumn = [];
  sorted.forEach(ev => {
    let colIdx = columnEnds.findIndex(endMs => endMs <= ev.start.getTime());
    if (colIdx === -1) {
      colIdx = columnEnds.length;
      columnEnds.push(ev.end.getTime());
    } else {
      columnEnds[colIdx] = ev.end.getTime();
    }
    withColumn.push({ ...ev, columnIndex: colIdx });
  });
  return withColumn;
};

const clusterOverlapping = events => {
  const sorted = [...events].sort((a, b) => a.start - b.start);
  const clusters = [];
  let current = null;
  sorted.forEach(ev => {
    if (current && ev.start < current.end) {
      current.events.push(ev);
      if (ev.end > current.end) current.end = ev.end;
    } else {
      current = { events: [ev], end: ev.end };
      clusters.push(current);
    }
  });
  return clusters;
};

export function layoutBookings(
  bookings,
  { hoursStart = 9, slotInterval = 30 } = {}
) {
  if (!bookings?.length) return [];
  const pxPerMinute = SLOT_HEIGHT / slotInterval;

  const prepared = bookings.map(b => {
    const start = new Date(b.scheduled_at);
    const duration = b.total_duration_minutes || slotInterval;
    const end = new Date(start.getTime() + duration * 60000);
    return { id: b.id, start, end, duration, booking: b };
  });

  const placed = assignColumnsGreedy(prepared);
  const clusters = clusterOverlapping(placed);

  const idToCluster = new Map();
  clusters.forEach(c => {
    const columnCount = c.events.reduce(
      (max, e) => Math.max(max, e.columnIndex + 1),
      0
    );
    c.columnCount = columnCount;
    c.events.forEach(e => idToCluster.set(e.id, c));
  });

  return placed.map(p => {
    const cluster = idToCluster.get(p.id);
    const columnCount = cluster.columnCount;
    const colWidthPct = 100 / columnCount;
    const basePct = p.columnIndex * colWidthPct;
    const overlapPct = columnCount > 1 ? 12 : 0;
    const widthPct = Math.min(colWidthPct + overlapPct, 100 - basePct);

    const dayStart = new Date(p.start);
    dayStart.setHours(hoursStart, 0, 0, 0);
    const top = differenceInMinutes(p.start, dayStart) * pxPerMinute;
    const height = Math.max(p.duration * pxPerMinute - 2, 22);

    return {
      booking: p.booking,
      layout: {
        top,
        height,
        leftPct: basePct,
        widthPct,
        zIndex: 10 + p.columnIndex,
        columnCount,
      },
    };
  });
}
