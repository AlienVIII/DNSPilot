export type AdaptiveLayout = {
  kind: 'phone' | 'tablet' | 'expanded';
  columns: 1 | 2;
  maxContentWidth: number;
  gap: number;
};

export function layoutForWidth(width: number): AdaptiveLayout;
