export function buildHistoryRows({ records = [], profiles = [] } = {}) {
  const names = new Map(profiles.filter((profile) => profile?.id).map((profile) => [profile.id, profile.name ?? profile.id]));
  return records.map((record) => {
    const recommendationID = text(record?.recommendation_profile_id);
    return {
      id: text(record?.id),
      title: scopeTitle(record?.scope),
      domainSummary: summary(record?.domains),
      recommendation: recommendationID ? names.get(recommendationID) ?? recommendationID : null,
      requiresRetest: Boolean(recommendationID),
    };
  });
}

function scopeTitle(scope) {
  if (scope === 'dns-tcp') return 'DNS + TCP';
  if (scope === 'dns-tcp-tls') return 'DNS + TCP + TLS';
  if (scope === 'dns-only') return 'DNS only';
  return 'DNS check';
}

function summary(domains) {
  const values = Array.isArray(domains) ? domains.filter(Boolean) : [];
  if (values.length === 0) return 'No domains';
  return values.length === 1 ? values[0] : `${values[0]} + ${values.length - 1} more`;
}

function text(value) {
  return String(value ?? '').trim();
}
