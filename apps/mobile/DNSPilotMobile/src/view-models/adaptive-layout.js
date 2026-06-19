export function layoutForWidth(width) {
  if (width >= 1200) {
    return {
      kind: "expanded",
      columns: 2,
      maxContentWidth: 1180,
      gap: 18,
    };
  }
  if (width >= 820) {
    return {
      kind: "tablet",
      columns: 2,
      maxContentWidth: 1080,
      gap: 16,
    };
  }
  return {
    kind: "phone",
    columns: 1,
    maxContentWidth: 640,
    gap: 14,
  };
}
