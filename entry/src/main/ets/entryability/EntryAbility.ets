import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { globalMessageStore } from '../common/util/GlobalDataStorage';
import LifecycleLog from '../common/util/LifecycleLog';

const TAG = '[EntryAbility]';
const DOMAIN = 0xff00;

export default class EntryAbility extends UIAbility {
  // Called when the application is created
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    globalMessageStore.message = '🎉 Application created!';
    hilog.info(DOMAIN, TAG, 'onCreate triggered.');
    LifecycleLog.add(globalMessageStore.message);
  }

  // Called when the window stage (UI) is created
  onWindowStageCreate(windowStage: window.WindowStage): void {
    globalMessageStore.message = '📱 UI is loading...';
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate triggered.');
    LifecycleLog.add(globalMessageStore.message);

    // Load the main page
    windowStage.loadContent('pages/Index', (err, data) => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: ' + JSON.stringify(err));
      }
    });

    // Listen for window stage events (lifecycle events)
    windowStage.on('windowStageEvent', (eventType) => {
      hilog.info(DOMAIN, TAG, `Window Stage Event: ${window.WindowStageEventType[eventType]}`);
      hilog.info(DOMAIN, 'A', `Current Message: ${globalMessageStore.message}`);

      switch (eventType) {
        case window.WindowStageEventType.SHOWN:
          // Application is visible (foreground)
          globalMessageStore.message = '👀 Application is visible (foreground)';
          LifecycleLog.add(globalMessageStore.message);

          // Show remaining lives if the game is not over
          if (!globalMessageStore.isGameOver) {
            console.info(`Remaining Lives: ${globalMessageStore.userLives}`);
          }
          break;
        case window.WindowStageEventType.HIDDEN:
          // Application is now in the background
          globalMessageStore.message = '🔒 Application is in background';
          LifecycleLog.add(globalMessageStore.message);

          // Reduce lives if game is not over
          if (!globalMessageStore.isGameOver) {
            globalMessageStore.userLives--;
            hilog.info(DOMAIN, TAG, `Life lost! Remaining Lives: ${globalMessageStore.userLives}`);

            // If lives are finished, end the game
            if (globalMessageStore.userLives <= 0) {
              globalMessageStore.isGameOver = true;
              globalMessageStore.message = 'You ran out of lives! Game over.';
              LifecycleLog.add(globalMessageStore.message);

              hilog.info(DOMAIN, TAG, 'Game Over!');
            } else {
              hilog.info(DOMAIN, TAG, `App is in background. Remaining Lives: ${globalMessageStore.userLives}`);
            }
          }
          break;
        case window.WindowStageEventType.ACTIVE:
          // Application is active
          globalMessageStore.message = '✅ Application is active';
          LifecycleLog.add(globalMessageStore.message);
          break;
        case window.WindowStageEventType.INACTIVE:
          // Application lost focus
          globalMessageStore.message = '⏸ Application is out of focus';
          LifecycleLog.add(globalMessageStore.message);
          break;
        case window.WindowStageEventType.RESUMED:
          // Application resumed interaction
          globalMessageStore.message = '🟢 Application resumed interaction';
          LifecycleLog.add(globalMessageStore.message);
          break;
        case window.WindowStageEventType.PAUSED:
          // Application is not interacting
          globalMessageStore.message = '🔇 Application is not interacting';
          LifecycleLog.add(globalMessageStore.message);
          break;
      }
    });
  }
}