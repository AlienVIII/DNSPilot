import type { DNSProfile, HistoryRecord } from '@/src/api/dnspilot';

export type HistoryPresentationRow = {
  id: string;
  title: string;
  domainSummary: string;
  recommendation: string | null;
  requiresRetest: boolean;
};

export function buildHistoryRows(input?: { records?: HistoryRecord[]; profiles?: DNSProfile[] }): HistoryPresentationRow[];
