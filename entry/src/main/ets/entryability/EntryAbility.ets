import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { globalMessageStore } from '../common/util/GlobalDataStorage';
import LifecycleLog from '../common/util/LifecycleLog';
import PageRouteTracker from '../common/util/PageRouteTracker';
import PageRoutes from '../common/constants/PageRoutes';
import { gameRepository } from '../data/GameRepository';
import { GameSessionState } from '../game/models/GameSessionState';

const TAG = '[EntryAbility]';
const DOMAIN = 0xff00;

export default class EntryAbility extends UIAbility {
  // Called when the application is created
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    globalMessageStore.message = '🎉 Application created!';
    hilog.info(DOMAIN, TAG, 'onCreate filesDir=%{public}s', this.context.filesDir);
    gameRepository.initialize(this.context.filesDir);
    hilog.info(DOMAIN, TAG, 'onCreate triggered.');
    LifecycleLog.add('app', globalMessageStore.message);
  }

  // Called when the window stage (UI) is created
  onWindowStageCreate(windowStage: window.WindowStage): void {
    globalMessageStore.message = '📱 UI is loading...';
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate filesDir=%{public}s', this.context.filesDir);
    gameRepository.configureStorage(this.context.filesDir);
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate triggered.');
    LifecycleLog.add('window-stage', globalMessageStore.message);

    // Load the main page
    windowStage.loadContent('pages/Index', (err, data) => {
      if (err && err.code !== 0) {
        hilog.error(DOMAIN, TAG, `loadContent failed: ${JSON.stringify(err)}`);
        return;
      }
      hilog.info(DOMAIN, TAG, 'loadContent success for pages/Index');
    });

    // Listen for window stage events (lifecycle events)
    try {
      windowStage.on('windowStageEvent', (eventType) => {
        hilog.info(DOMAIN, TAG, `Window Stage Event: ${window.WindowStageEventType[eventType]}`);
        hilog.info(DOMAIN, 'A', `Current Message: ${globalMessageStore.message}`);

        switch (eventType) {
          case window.WindowStageEventType.SHOWN: {
            // Application is visible (foreground)
            globalMessageStore.message = '👀 Application is visible (foreground)';
            const shouldShowResumeBanner = this.shouldShowResumeBanner();
            LifecycleLog.add('foreground', globalMessageStore.message);
            this.showLifecycleBanner(shouldShowResumeBanner
              ? 'Returned to the foreground. Background handling follows your selected policy.'
              : '');
            this.handleTimedResume();

            // Show remaining lives if the game is not over
            if (!globalMessageStore.isGameOver) {
              console.info(`Remaining Lives: ${globalMessageStore.userLives}`);
            }
            break;
          }
          case window.WindowStageEventType.HIDDEN: {
            // Application is now in the background
            globalMessageStore.message = '🔒 Application is in background';
            LifecycleLog.add('background', globalMessageStore.message);
            const backgroundBanner = this.backgroundPolicyBanner();
            this.showLifecycleBanner(backgroundBanner);
            let pendingGameBanner = PageRouteTracker.isCurrentPage(PageRoutes.GAME) ? backgroundBanner : '';

            if (PageRouteTracker.isCurrentPage(PageRoutes.GAME) && PageRouteTracker.getCurrentGameMode() === 'timed') {
              const timedSettings = gameRepository.getSettings();
              gameRepository.setTimedSessionBackgroundPaused(timedSettings.timedBackgroundPolicy === 'pause');
              if (timedSettings.timedBackgroundPolicy === 'log-only') {
                gameRepository.markTimedSessionBackgroundStarted(new Date().getTime());
                pendingGameBanner = 'Returned to the foreground. Timed countdown was adjusted for time spent away.';
              } else {
                pendingGameBanner = 'Returned to the foreground. Timed countdown was paused while you were away.';
              }
            }

            if (this.shouldApplyBackgroundPenalty()) {
              const backgroundPenaltySession = this.createBackgroundPenaltySession();
              const penaltyMessage = this.backgroundPenaltyMessage(backgroundPenaltySession.lives - 1);
              if (gameRepository.recordBackgroundPenalty(backgroundPenaltySession, penaltyMessage)) {
                globalMessageStore.userLives = backgroundPenaltySession.lives;
                globalMessageStore.isGameOver = backgroundPenaltySession.isGameOver;
                pendingGameBanner = penaltyMessage;
                hilog.info(DOMAIN, TAG, `Life lost! Remaining Lives: ${globalMessageStore.userLives}`);

                // If lives are finished, end the game
                if (globalMessageStore.userLives <= 0) {
                  globalMessageStore.message = penaltyMessage;
                  LifecycleLog.add('game-over', globalMessageStore.message);

                  hilog.info(DOMAIN, TAG, 'Game Over!');
                } else {
                  hilog.info(DOMAIN, TAG, `App is in background. Remaining Lives: ${globalMessageStore.userLives}`);
                }
              }
            }
            if (pendingGameBanner !== '') {
              gameRepository.setPendingLifecycleBanner(pendingGameBanner);
            }
            break;
          }
          case window.WindowStageEventType.ACTIVE:
            // Application is active
            globalMessageStore.message = '✅ Application is active';
            LifecycleLog.add('active', globalMessageStore.message);
            break;
          case window.WindowStageEventType.INACTIVE:
            // Application lost focus
            globalMessageStore.message = '⏸ Application is out of focus';
            LifecycleLog.add('inactive', globalMessageStore.message);
            break;
          case window.WindowStageEventType.RESUMED:
            // Application resumed interaction
            globalMessageStore.message = '🟢 Application resumed interaction';
            LifecycleLog.add('resumed', globalMessageStore.message);
            break;
          case window.WindowStageEventType.PAUSED:
            // Application is not interacting
            globalMessageStore.message = '🔇 Application is not interacting';
            LifecycleLog.add('paused', globalMessageStore.message);
            break;
        }
      });
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'windowStage listener failed %{public}s', JSON.stringify(error));
    }
  }

  private showLifecycleBanner(message: string): void {
    gameRepository.setLifecycleBanner(message);
  }

  private shouldShowResumeBanner(): boolean {
    return gameRepository.hasPendingLifecycleBanner();
  }

  private backgroundPolicyBanner(): string {
    const settings = gameRepository.getSettings();
    if (PageRouteTracker.getCurrentGameMode() === 'timed') {
      return settings.timedBackgroundPolicy === 'log-only'
        ? 'Timed session backgrounded: event recorded, countdown will catch up when you return.'
        : 'Timed session backgrounded: countdown paused until you return.';
    }
    if (settings.backgroundPolicy === 'log-only') {
      return 'Paused in background: no life was lost, but the event was recorded.';
    }
    return 'Paused in background: classic mode still costs a life when this policy is enabled.';
  }

  private backgroundPenaltyMessage(remainingLives: number): string {
    return remainingLives <= 0
      ? 'You lost your last life while away. Game over.'
      : `You lost a life while away. Lives remaining: ${remainingLives}.`;
  }

  private createBackgroundPenaltySession(): GameSessionState {
    const savedSession = gameRepository.getLastSession();
    return {
      mode: savedSession.mode,
      lives: globalMessageStore.userLives,
      score: savedSession.score,
      streak: savedSession.streak,
      bestStreak: savedSession.bestStreak,
      correctCount: savedSession.correctCount,
      wrongCount: savedSession.wrongCount,
      completedRounds: savedSession.completedRounds,
      sequenceIndex: savedSession.sequenceIndex,
      turnIndex: savedSession.turnIndex,
      roundDelayMs: savedSession.roundDelayMs,
      timeLimitMs: savedSession.timeLimitMs,
      remainingTimeMs: savedSession.remainingTimeMs,
      isGameOver: globalMessageStore.isGameOver
    };
  }

  private shouldApplyBackgroundPenalty(): boolean {
    const settings = gameRepository.getSettings();
    return settings.backgroundPenaltyEnabled && settings.backgroundPolicy === 'penalize' &&
    PageRouteTracker.isCurrentPage(PageRoutes.GAME) &&
      PageRouteTracker.getCurrentGameMode() === 'classic' &&
    gameRepository.hasActiveClassicSession() &&
      !globalMessageStore.isGameOver;
  }

  private handleTimedResume(): void {
    if (PageRouteTracker.isCurrentPage(PageRoutes.GAME) && PageRouteTracker.getCurrentGameMode() === 'timed') {
      gameRepository.setTimedSessionBackgroundPaused(false);
    }
  }
}
