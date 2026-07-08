import React from 'react';
import type { DimensionValue } from 'react-native';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  useWindowDimensions,
  View,
} from 'react-native';

import { layoutForWidth } from '@/src/view-models/adaptive-layout';

export const palette = {
  background: '#f8fafc',
  surface: '#ffffff',
  text: '#111827',
  muted: '#64748b',
  border: '#dbe4ef',
  blue: '#2563eb',
  blueSoft: '#dbeafe',
  green: '#15803d',
  greenSoft: '#dcfce7',
  amber: '#b45309',
  amberSoft: '#fef3c7',
  red: '#b91c1c',
  redSoft: '#fee2e2',
  slate: '#334155',
};

export function Screen({ children }: { children: React.ReactNode }) {
  const { width } = useWindowDimensions();
  const layout = layoutForWidth(width);
  return (
    <ScrollView
      contentInsetAdjustmentBehavior="automatic"
      keyboardShouldPersistTaps="handled"
      style={styles.screen}
      contentContainerStyle={[
        styles.screenContent,
        {
          gap: layout.gap,
          maxWidth: layout.maxContentWidth,
          width: '100%',
        },
      ]}>
      {children}
    </ScrollView>
  );
}

export function AdaptiveColumns({ children }: { children: React.ReactNode }) {
  const { width } = useWindowDimensions();
  const layout = layoutForWidth(width);
  const childWidth = (layout.columns === 1 ? '100%' : `${(100 - layout.gap / 10) / 2}%`) as DimensionValue;
  const childMinWidth = (layout.columns === 1 ? '100%' : 320) as DimensionValue;

  return (
    <View style={[styles.adaptiveColumns, { gap: layout.gap }]}>
      {React.Children.map(children, (child, index) => (
        <View key={index} style={{ flexGrow: 1, minWidth: childMinWidth, width: childWidth }}>
          {child}
        </View>
      ))}
    </View>
  );
}

export function Section({
  title,
  subtitle,
  action,
  children,
}: {
  title: string;
  subtitle?: string;
  action?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <View style={styles.section}>
      <View style={styles.sectionHeaderRow}>
        <View style={styles.sectionHeader}>
          <Text selectable style={styles.sectionTitle}>
            {title}
          </Text>
          {subtitle ? (
            <Text selectable style={styles.sectionSubtitle}>
              {subtitle}
            </Text>
          ) : null}
        </View>
        {action ? <View style={styles.sectionAction}>{action}</View> : null}
      </View>
      {children}
    </View>
  );
}

export function Row({ children }: { children: React.ReactNode }) {
  return <View style={styles.row}>{children}</View>;
}

export function Metric({ label, value, tone = 'neutral' }: { label: string; value: string | number; tone?: Tone }) {
  return (
    <View style={[styles.metric, toneStyle(tone)]}>
      <Text selectable style={styles.metricValue}>
        {value}
      </Text>
      <Text selectable style={styles.metricLabel}>
        {label}
      </Text>
    </View>
  );
}

export function Button({
  label,
  onPress,
  variant = 'primary',
  disabled = false,
  loading = false,
  accessibilityLabel,
}: {
  label: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary' | 'danger';
  disabled?: boolean;
  loading?: boolean;
  accessibilityLabel?: string;
}) {
  const unavailable = disabled || loading;
  return (
    <Pressable
      accessibilityLabel={accessibilityLabel ?? label}
      accessibilityRole="button"
      accessibilityState={{ busy: loading, disabled: unavailable }}
      disabled={unavailable}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        buttonStyle(variant),
        unavailable && styles.buttonDisabled,
        pressed && !unavailable ? styles.buttonPressed : null,
      ]}>
      {loading ? <ActivityIndicator color={variant === 'primary' ? '#fff' : palette.blue} /> : null}
      <Text style={[styles.buttonText, variant === 'primary' ? styles.buttonTextPrimary : null]}>{label}</Text>
    </Pressable>
  );
}

export function HelpButton({
  label,
  onPress,
}: {
  label: string;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityLabel={label}
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.helpButton, pressed ? styles.buttonPressed : null]}>
      <Text style={styles.helpButtonText}>?</Text>
    </Pressable>
  );
}

export function TextField({
  label,
  value,
  onChangeText,
  placeholder,
  multiline = false,
  keyboardType,
}: {
  label: string;
  value: string;
  onChangeText: (value: string) => void;
  placeholder?: string;
  multiline?: boolean;
  keyboardType?: 'default' | 'numeric';
}) {
  return (
    <View style={styles.field}>
      <Text style={styles.label}>{label}</Text>
      <TextInput
        autoCapitalize="none"
        autoCorrect={false}
        accessibilityLabel={label}
        keyboardType={keyboardType}
        multiline={multiline}
        onChangeText={onChangeText}
        placeholder={placeholder}
        placeholderTextColor="#94a3b8"
        style={[styles.input, multiline ? styles.multilineInput : null]}
        value={value}
      />
    </View>
  );
}

export function Segmented<T extends string>({
  options,
  value,
  onChange,
}: {
  options: { label: string; value: T }[];
  value: T;
  onChange: (value: T) => void;
}) {
  return (
    <View style={styles.segmented}>
      {options.map((option) => {
        const selected = option.value === value;
        return (
          <Pressable
            accessibilityLabel={option.label}
            accessibilityRole="button"
            accessibilityState={{ selected }}
            key={option.value}
            onPress={() => onChange(option.value)}
            style={[styles.segment, selected ? styles.segmentSelected : null]}>
            <Text style={[styles.segmentText, selected ? styles.segmentTextSelected : null]}>{option.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

export function ToggleRow({
  label,
  value,
  onValueChange,
  subtitle,
}: {
  label: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
  subtitle?: string;
}) {
  return (
    <View style={styles.toggleRow}>
      <View style={styles.toggleText}>
        <Text style={styles.toggleLabel}>{label}</Text>
        {subtitle ? <Text style={styles.toggleSubtitle}>{subtitle}</Text> : null}
      </View>
      <Switch
        accessibilityHint={subtitle}
        accessibilityLabel={label}
        accessibilityRole="switch"
        accessibilityState={{ checked: value }}
        value={value}
        onValueChange={onValueChange}
      />
    </View>
  );
}

export function Pill({
  label,
  selected = false,
  onPress,
  tone = 'neutral',
}: {
  label: string;
  selected?: boolean;
  onPress?: () => void;
  tone?: Tone;
}) {
  const interactive = Boolean(onPress);
  return (
    <Pressable
      accessibilityLabel={label}
      accessibilityRole={interactive ? 'button' : undefined}
      accessibilityState={interactive ? { selected } : undefined}
      disabled={!interactive}
      onPress={onPress}
      style={[styles.pill, toneStyle(tone), selected ? styles.pillSelected : null]}>
      <Text style={[styles.pillText, selected ? styles.pillTextSelected : null]}>{label}</Text>
    </Pressable>
  );
}

export function ErrorBanner({ message }: { message?: string | null }) {
  if (!message) {
    return null;
  }
  return (
    <View style={styles.errorBanner}>
      <Text selectable style={styles.errorText}>
        {message}
      </Text>
    </View>
  );
}

export function CodeBlock({ text }: { text: string }) {
  return (
    <Text selectable style={styles.codeBlock}>
      {text}
    </Text>
  );
}

export function EmptyState({ text }: { text: string }) {
  return (
    <View style={styles.emptyState}>
      <Text selectable style={styles.emptyText}>
        {text}
      </Text>
    </View>
  );
}

type Tone = 'neutral' | 'blue' | 'green' | 'amber' | 'red';

function toneStyle(tone: Tone) {
  switch (tone) {
    case 'blue':
      return { backgroundColor: palette.blueSoft, borderColor: '#bfdbfe' };
    case 'green':
      return { backgroundColor: palette.greenSoft, borderColor: '#bbf7d0' };
    case 'amber':
      return { backgroundColor: palette.amberSoft, borderColor: '#fde68a' };
    case 'red':
      return { backgroundColor: palette.redSoft, borderColor: '#fecaca' };
    default:
      return { backgroundColor: palette.surface, borderColor: palette.border };
  }
}

function buttonStyle(variant: 'primary' | 'secondary' | 'danger') {
  switch (variant) {
    case 'danger':
      return { backgroundColor: palette.redSoft, borderColor: '#fecaca' };
    case 'secondary':
      return { backgroundColor: palette.surface, borderColor: palette.border };
    default:
      return { backgroundColor: palette.blue, borderColor: palette.blue };
  }
}

const styles = StyleSheet.create({
  screen: {
    backgroundColor: palette.background,
    flex: 1,
  },
  screenContent: {
    alignSelf: 'center',
    gap: 14,
    padding: 16,
    paddingBottom: 32,
  },
  adaptiveColumns: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  section: {
    gap: 12,
  },
  sectionHeader: {
    flex: 1,
    gap: 3,
  },
  sectionHeaderRow: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: 12,
    justifyContent: 'space-between',
  },
  sectionAction: {
    alignItems: 'flex-end',
    paddingTop: 2,
  },
  sectionTitle: {
    color: palette.text,
    fontSize: 20,
    fontWeight: '800',
  },
  sectionSubtitle: {
    color: palette.muted,
    fontSize: 13,
    lineHeight: 18,
  },
  row: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  metric: {
    borderRadius: 8,
    borderWidth: 1,
    flexBasis: '31%',
    flexGrow: 1,
    gap: 3,
    minHeight: 70,
    padding: 12,
  },
  metricValue: {
    color: palette.text,
    fontSize: 22,
    fontVariant: ['tabular-nums'],
    fontWeight: '800',
  },
  metricLabel: {
    color: palette.muted,
    fontSize: 12,
  },
  button: {
    alignItems: 'center',
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    minHeight: 44,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  buttonDisabled: {
    opacity: 0.5,
  },
  buttonPressed: {
    opacity: 0.75,
  },
  buttonText: {
    color: palette.text,
    fontSize: 14,
    fontWeight: '700',
  },
  buttonTextPrimary: {
    color: '#fff',
  },
  helpButton: {
    alignItems: 'center',
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 999,
    borderWidth: 1,
    height: 36,
    justifyContent: 'center',
    width: 36,
  },
  helpButtonText: {
    color: palette.blue,
    fontSize: 18,
    fontWeight: '900',
    lineHeight: 22,
  },
  field: {
    flexGrow: 1,
    gap: 6,
    minWidth: 150,
  },
  label: {
    color: palette.slate,
    fontSize: 13,
    fontWeight: '700',
  },
  input: {
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 8,
    borderWidth: 1,
    color: palette.text,
    fontSize: 15,
    minHeight: 44,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  multilineInput: {
    minHeight: 96,
    textAlignVertical: 'top',
  },
  segmented: {
    backgroundColor: '#e2e8f0',
    borderRadius: 8,
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 4,
    padding: 4,
  },
  segment: {
    borderRadius: 7,
    flexGrow: 1,
    minHeight: 36,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  segmentSelected: {
    backgroundColor: palette.surface,
  },
  segmentText: {
    color: palette.muted,
    fontSize: 13,
    fontWeight: '700',
    textAlign: 'center',
  },
  segmentTextSelected: {
    color: palette.blue,
  },
  toggleRow: {
    alignItems: 'center',
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 12,
    justifyContent: 'space-between',
    padding: 12,
  },
  toggleText: {
    flex: 1,
    gap: 3,
  },
  toggleLabel: {
    color: palette.text,
    fontSize: 14,
    fontWeight: '700',
  },
  toggleSubtitle: {
    color: palette.muted,
    fontSize: 12,
  },
  pill: {
    borderRadius: 999,
    borderWidth: 1,
    paddingHorizontal: 11,
    paddingVertical: 7,
  },
  pillSelected: {
    backgroundColor: palette.blue,
    borderColor: palette.blue,
  },
  pillText: {
    color: palette.slate,
    fontSize: 12,
    fontWeight: '700',
  },
  pillTextSelected: {
    color: '#fff',
  },
  errorBanner: {
    backgroundColor: palette.redSoft,
    borderColor: '#fecaca',
    borderRadius: 8,
    borderWidth: 1,
    padding: 12,
  },
  errorText: {
    color: palette.red,
    fontSize: 13,
    lineHeight: 18,
  },
  codeBlock: {
    backgroundColor: '#0f172a',
    borderRadius: 8,
    color: '#e2e8f0',
    fontFamily: 'SpaceMono',
    fontSize: 11,
    lineHeight: 16,
    padding: 12,
  },
  emptyState: {
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 8,
    borderWidth: 1,
    padding: 14,
  },
  emptyText: {
    color: palette.muted,
    fontSize: 13,
  },
});
