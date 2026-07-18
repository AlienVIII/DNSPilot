import React from 'react';
import { Modal, Text, View } from 'react-native';

import { Button, HelpButton, Row, palette } from '@/src/components/ui';
import { useDNSPilot } from '@/src/state/dnspilot-context';

export function TutorialHeaderButton() {
  const { openTutorial, t } = useDNSPilot();
  return <HelpButton label={t('tutorial.openA11y')} onPress={openTutorial} />;
}

export function AppTutorial() {
  const { completeTutorial, dismissTutorial, t, tutorialVisible } = useDNSPilot();

  return (
    <Modal animationType="slide" transparent visible={tutorialVisible} onRequestClose={dismissTutorial}>
      <View style={overlayStyle}>
        <View style={sheetStyle} accessibilityViewIsModal>
          <Text selectable style={titleStyle}>{t('tutorial.title')}</Text>
          <Text selectable style={subtitleStyle}>{t('tutorial.subtitle')}</Text>
          <TutorialStep title={t('tutorial.measure.title')} body={t('tutorial.measure.body')} />
          <TutorialStep title={t('tutorial.review.title')} body={t('tutorial.review.body')} />
          <TutorialStep title={t('tutorial.setup.title')} body={t('tutorial.setup.body')} />
          <Row>
            <Button label={t('tutorial.skip')} onPress={completeTutorial} variant="secondary" />
            <Button label={t('tutorial.done')} onPress={completeTutorial} />
          </Row>
        </View>
      </View>
    </Modal>
  );
}

function TutorialStep({ title, body }: { title: string; body: string }) {
  return (
    <View style={stepStyle}>
      <Text selectable style={stepTitleStyle}>{title}</Text>
      <Text selectable style={stepBodyStyle}>{body}</Text>
    </View>
  );
}

const overlayStyle = { backgroundColor: 'rgba(15, 23, 42, 0.42)', flex: 1, justifyContent: 'flex-end' } as const;
const sheetStyle = { backgroundColor: palette.background, borderTopLeftRadius: 8, borderTopRightRadius: 8, gap: 14, padding: 20 } as const;
const titleStyle = { color: palette.text, fontSize: 24, fontWeight: '800' } as const;
const subtitleStyle = { color: palette.muted, fontSize: 15, lineHeight: 21 } as const;
const stepStyle = { backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 3, padding: 12 } as const;
const stepTitleStyle = { color: palette.text, fontSize: 15, fontWeight: '800' } as const;
const stepBodyStyle = { color: palette.muted, fontSize: 13, lineHeight: 18 } as const;
