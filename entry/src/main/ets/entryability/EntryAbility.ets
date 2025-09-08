import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GlobalMessageStore } from '../common/util/GlobalDataStorage';
import LifecycleLog from '../common/util/LifecycleLog';

const TAG = '[EntryAbility]';
const DOMAIN = 0xff00;

export default class EntryAbility extends UIAbility {
  // Called when the application is created
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    GlobalMessageStore.message = '🎉 Application created!';
    hilog.info(DOMAIN, TAG, 'onCreate triggered.');
    LifecycleLog.add(GlobalMessageStore.message);
  }

  // Called when the window stage (UI) is created
  onWindowStageCreate(windowStage: window.WindowStage): void {
    GlobalMessageStore.message = '📱 UI is loading...';
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate triggered.');
    LifecycleLog.add(GlobalMessageStore.message);

    // Load the main page
    windowStage.loadContent('pages/Index', (err, data) => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: ' + JSON.stringify(err));
      }
    });

    // Listen for window stage events (lifecycle events)
    windowStage.on('windowStageEvent', (eventType) => {
      hilog.info(DOMAIN, TAG, `Window Stage Event: ${window.WindowStageEventType[eventType]}`);
      hilog.info(DOMAIN, "A", `Current Message: ${GlobalMessageStore.message}`);

      switch (eventType) {
        case window.WindowStageEventType.SHOWN:
          // Application is visible (foreground)
          GlobalMessageStore.message = '👀 Application is visible (foreground)';
          LifecycleLog.add(GlobalMessageStore.message);

          // Show remaining lives if the game is not over
          if (!GlobalMessageStore.isGameOver) {
            console.log(`Remaining Lives: ${GlobalMessageStore.userLives}`);
          }
          break;
        case window.WindowStageEventType.HIDDEN:
          // Application is now in the background
          GlobalMessageStore.message = '🔒 Application is in background';
          LifecycleLog.add(GlobalMessageStore.message);

          // Reduce lives if game is not over
          if (!GlobalMessageStore.isGameOver) {
            GlobalMessageStore.userLives--;
            hilog.info(DOMAIN, TAG, `Life lost! Remaining Lives: ${GlobalMessageStore.userLives}`);

            // If lives are finished, end the game
            if (GlobalMessageStore.userLives <= 0) {
              GlobalMessageStore.isGameOver = true;
              GlobalMessageStore.message = 'You ran out of lives! Game over.';
              LifecycleLog.add(GlobalMessageStore.message);

              hilog.info(DOMAIN, TAG, 'Game Over!');
            } else {
              hilog.info(DOMAIN, TAG, `App is in background. Remaining Lives: ${GlobalMessageStore.userLives}`);
            }
          }
          break;
        case window.WindowStageEventType.ACTIVE:
          // Application is active
          GlobalMessageStore.message = '✅ Application is active';
          LifecycleLog.add(GlobalMessageStore.message);
          break;
        case window.WindowStageEventType.INACTIVE:
          // Application lost focus
          GlobalMessageStore.message = '⏸ Application is out of focus';
          LifecycleLog.add(GlobalMessageStore.message);
          break;
        case window.WindowStageEventType.RESUMED:
          // Application resumed interaction
          GlobalMessageStore.message = '🟢 Application resumed interaction';
          LifecycleLog.add(GlobalMessageStore.message);
          break;
        case window.WindowStageEventType.PAUSED:
          // Application is not interacting
          GlobalMessageStore.message = '🔇 Application is not interacting';
          LifecycleLog.add(GlobalMessageStore.message);
          break;
      }
    });
  }
}