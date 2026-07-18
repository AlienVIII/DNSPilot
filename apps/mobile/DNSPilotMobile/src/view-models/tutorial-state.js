export const currentTutorialVersion = 1;

export function shouldShowTutorial({ preferencesLoaded, tutorialCompletionVersion, tutorialVersion = currentTutorialVersion }) {
  return Boolean(preferencesLoaded) && normalizeVersion(tutorialCompletionVersion) < normalizeVersion(tutorialVersion);
}

function normalizeVersion(value) {
  const number = Number(value);
  return Number.isInteger(number) && number >= 0 ? number : 0;
}
