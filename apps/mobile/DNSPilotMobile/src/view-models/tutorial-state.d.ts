export const currentTutorialVersion: number;

export function shouldShowTutorial(input: {
  preferencesLoaded: boolean;
  tutorialCompletionVersion?: number;
  tutorialVersion?: number;
}): boolean;
