import assert from "node:assert/strict";
import test from "node:test";

import { currentTutorialVersion, shouldShowTutorial } from "./tutorial-state.js";

test("does not show a tutorial until preferences have loaded", () => {
  assert.equal(
    shouldShowTutorial({ preferencesLoaded: false, tutorialCompletionVersion: 0 }),
    false
  );
});

test("shows the current tutorial until Skip or Done persists its version", () => {
  assert.equal(currentTutorialVersion, 1);
  assert.equal(
    shouldShowTutorial({ preferencesLoaded: true, tutorialCompletionVersion: 0 }),
    true
  );
  assert.equal(
    shouldShowTutorial({ preferencesLoaded: true, tutorialCompletionVersion: currentTutorialVersion }),
    false
  );
});

test("shows a newer tutorial after a version bump", () => {
  assert.equal(
    shouldShowTutorial({ preferencesLoaded: true, tutorialCompletionVersion: 1, tutorialVersion: 2 }),
    true
  );
});
