import CommonConstants from '../common/constants/CommonConstants';
import PageRoutes from '../common/constants/PageRoutes';
import { HapticEvent, wearableHapticsService } from '../common/services/WearableHapticsService';
import AppNavigator from '../common/util/AppNavigator';
import { globalMessageStore as GlobalDataStore } from '../common/util/GlobalDataStorage';
import PageRouteTracker from '../common/util/PageRouteTracker';
import { ClassicSessionSnapshot } from '../data/models/GameRepositoryTypes';
import { gameRepository } from '../data/GameRepository';
import { GameEngine } from '../game/services/GameEngine';
import { GameMode } from '../game/models/GameMode';
import { GameRound } from '../game/models/GameRound';
import { GameResult } from '../game/models/GameResult';
import { GameSessionState } from '../game/models/GameSessionState';

class GameRouteParams {
  mode: string = GameMode.CLASSIC;
  resumeClassic: string = 'false';
}

class ResultRouteParams {
  sessionId: string = '';
  mode: string = GameMode.CLASSIC;
  reason: string = '';
  summary: string = '';
}

@Component
export struct Game {
  @StorageLink('userLives') lives: number = GlobalDataStore.userLives;
  @StorageLink('gameOver') isGameOver: boolean = GlobalDataStore.isGameOver;

  @State displayMessage: string = '';
  @State options: number[] = [1, 3];
  @State modeLabel: string = 'Classic';
  @State scoreText: string = 'Score 0';
  @State streakText: string = 'Streak 0';
  @State progressText: string = '';
  @State timerText: string = '';
  @State lifecycleBanner: string = '';

  private readonly gameEngine: GameEngine = new GameEngine();
  private readonly haptics = wearableHapticsService;
  private session: GameSessionState | null = null;
  private currentRound: GameRound | null = null;
  private currentMode: GameMode = GameMode.CLASSIC;
  private roundToken: number = 0;
  private timerHandle: number | null = null;
  private inputLocked: boolean = false;

  aboutToAppear() {
    this.startGameFromRoute();
  }

  aboutToDisappear() {
    this.stopTimer();
  }

  onPageShow() {
    PageRouteTracker.setCurrentPage(PageRoutes.GAME);
    this.syncSessionFromRepository();
    this.applyTimedBackgroundElapsed();
    this.lifecycleBanner = gameRepository.consumeLifecycleBanner();
    this.updateHud();
    this.ensureTimer();
  }

  private startGameFromRoute() {
    this.stopTimer();
    gameRepository.setTimedSessionBackgroundPaused(false);
    gameRepository.clearTimedSessionBackgroundStarted();
    this.lifecycleBanner = '';
    this.inputLocked = false;
    const params = AppNavigator.consumeParams<GameRouteParams>(PageRoutes.GAME);
    const requestedMode = params?.mode as GameMode | undefined;
    const mode = requestedMode === GameMode.TIMED || requestedMode === GameMode.STREAK ? requestedMode : GameMode.CLASSIC;
    const shouldResumeClassic = params?.resumeClassic === 'true';
    this.currentMode = mode;
    PageRouteTracker.setCurrentGameMode(mode);
    this.roundToken += 1;

    const savedSession = gameRepository.getLastSession();
    if (mode === GameMode.CLASSIC && shouldResumeClassic && this.isRestorableClassicSession(savedSession)) {
      this.restoreClassicSession(savedSession);
      this.updateHud();
      return;
    }

    gameRepository.clearLifecycleBanner();

    const bundle = this.gameEngine.createSession(mode);
    this.session = bundle.session;
    this.currentRound = bundle.round;
    this.modeLabel = mode.charAt(0).toUpperCase() + mode.slice(1);
    if (mode === GameMode.CLASSIC) {
      gameRepository.setClassicSessionActive(true);
    }
    this.syncRoundState(bundle.round);
    this.displayMessage = 'Pick a number';
    this.syncStorageState();
    if (mode === GameMode.CLASSIC) {
      gameRepository.saveClassicProgress(this.session, this.displayMessage);
    }
    this.updateHud();
    this.ensureTimer();
  }

  private restoreClassicSession(savedSession: ClassicSessionSnapshot) {
    this.session = this.createSessionFromSnapshot(savedSession);
    this.currentRound = this.session.isGameOver ? null : this.restoreRoundFromSnapshot(savedSession);
    gameRepository.setClassicSessionActive(!this.session.isGameOver);
    if (this.currentRound) {
      this.syncRoundState(this.currentRound);
    }
    this.displayMessage = savedSession.message ||
      (this.session.isGameOver ? 'You ran out of lives! Game over.' : '❤️'.repeat(this.session.lives));
    this.syncStorageState();
  }

  private syncSessionFromRepository() {
    if (!this.session || this.currentMode !== GameMode.CLASSIC || this.session.mode !== GameMode.CLASSIC) {
      return;
    }
    const savedSession = gameRepository.getLastSession();
    if (savedSession.updatedAt <= 0 || savedSession.mode !== GameMode.CLASSIC) {
      return;
    }
    this.session.lives = savedSession.lives;
    this.session.isGameOver = savedSession.gameOver;
    this.session.score = savedSession.score;
    this.session.streak = savedSession.streak;
    this.session.bestStreak = savedSession.bestStreak;
    this.session.correctCount = savedSession.correctCount;
    this.session.wrongCount = savedSession.wrongCount;
    this.session.completedRounds = savedSession.completedRounds;
    this.session.sequenceIndex = savedSession.sequenceIndex;
    this.session.turnIndex = savedSession.turnIndex;
    this.session.roundDelayMs = savedSession.roundDelayMs;
    this.session.timeLimitMs = savedSession.timeLimitMs;
    this.session.remainingTimeMs = savedSession.remainingTimeMs;
    this.currentRound = this.session.isGameOver ? null : this.currentRound;
    if (!this.session.isGameOver && !this.currentRound) {
      this.currentRound = this.restoreRoundFromSnapshot(savedSession);
      if (this.currentRound) {
        this.syncRoundState(this.currentRound);
      }
    }
    if (savedSession.message) {
      this.displayMessage = savedSession.message;
    }
    this.syncStorageState();
  }

  private syncRoundState(round: GameRound) {
    this.options = round.options;
  }

  private syncStorageState() {
    if (this.session) {
      this.lives = this.session.lives;
      this.isGameOver = this.session.isGameOver;
    }
  }

  private updateHud() {
    if (!this.session) {
      return;
    }
    this.scoreText = `Score ${this.session.score}`;
    this.streakText = `Streak ${this.session.streak}${this.currentMode === GameMode.STREAK ? ` / ${this.gameEngine.getModeConfig(GameMode.STREAK).targetStreak}` : ''}`;
    this.progressText = this.currentMode === GameMode.STREAK
      ? `Goal ${this.session.streak}/${this.gameEngine.getModeConfig(GameMode.STREAK).targetStreak}`
      : `Rounds ${this.session.completedRounds}`;
    this.timerText = this.currentMode === GameMode.TIMED ? `Time ${Math.ceil(this.session.remainingTimeMs / 1000)}s` : '';
    if (this.currentMode === GameMode.TIMED) {
      if (gameRepository.isTimedSessionBackgroundPaused()) {
        this.displayMessage = 'Timed session paused while the app was in the background.';
      } else {
        this.displayMessage = this.session.isGameOver ? 'Time up!' : this.displayMessage || 'Beat the clock!';
      }
    }
  }

  private applyTimedBackgroundElapsed() {
    if (!this.session || this.session.mode !== GameMode.TIMED || this.session.isGameOver || gameRepository.isTimedSessionBackgroundPaused()) {
      return;
    }
    const elapsed = gameRepository.consumeTimedSessionBackgroundElapsed(Date.now());
    if (elapsed > 0) {
      this.gameEngine.advanceTimer(this.session, elapsed);
      this.syncStorageState();
    }
  }

  private ensureTimer() {
    this.stopTimer();
    if (!this.session || this.session.mode !== GameMode.TIMED || this.session.isGameOver || gameRepository.isTimedSessionBackgroundPaused()) {
      return;
    }
      this.timerHandle = setInterval((): void => this.tickTimer(), 1000);
  }

  private tickTimer() {
    if (!this.session || !this.currentRound || this.session.mode !== GameMode.TIMED || this.session.isGameOver) {
      this.stopTimer();
      return;
    }
    if (gameRepository.isTimedSessionBackgroundPaused()) {
      this.stopTimer();
      this.displayMessage = 'Timed session paused while the app was in the background.';
      this.updateHud();
      return;
    }
    const result = this.gameEngine.advanceTimer(this.session, 1000);
    this.syncStorageState();
    this.updateHud();
    if (result) {
      this.finishSession(result, 'Time expired! Session complete.');
    }
  }

  private stopTimer() {
    if (this.timerHandle) {
      clearInterval(this.timerHandle);
      this.timerHandle = null;
    }
  }

  private finishSession(result: GameResult, summary: string) {
    this.stopTimer();
    gameRepository.setTimedSessionBackgroundPaused(false);
    this.inputLocked = false;
    if (this.session) {
      this.session.isGameOver = true;
    }
    this.isGameOver = true;
    this.displayMessage = summary;
    this.triggerHaptic('session-complete');
    gameRepository.recordCompletedSession(this.session!, result, summary);
    this.routeToResult(result, summary);
  }

  private routeToResult(result: GameResult, summary: string): void {
    PageRouteTracker.setCurrentPage(PageRoutes.RESULT);
    const params: ResultRouteParams = new ResultRouteParams();
    params.sessionId = `${result.completedAt}`;
    params.mode = result.mode;
    params.reason = result.reason;
    params.summary = summary;
    AppNavigator.push(PageRoutes.RESULT, params);
  }

  handleGuess(guess: number) {
    if (!this.session || !this.currentRound || this.isGameOver || this.inputLocked) {
      return;
    }
    this.inputLocked = true;
    const turnResult = this.gameEngine.submitGuess(this.session, this.currentRound, guess);
    this.displayMessage = turnResult.message;
    if (turnResult.isCorrect) {
      this.triggerHaptic('correct');
      if (this.session.streak > 0 && this.session.streak % 3 === 0) {
        this.triggerHaptic('streak-milestone');
      }
      if (turnResult.result && this.session.mode === GameMode.STREAK) {
        this.triggerHaptic('streak-complete');
      }
    } else {
      this.triggerHaptic('wrong');
    }
    this.syncStorageState();
    this.updateHud();
    if (turnResult.result) {
      this.finishSession(turnResult.result, turnResult.message);
      return;
    }
    if (this.session.mode === GameMode.CLASSIC) {
      gameRepository.saveClassicProgress(this.session, this.displayMessage);
    }
    if (turnResult.nextRound) {
      const nextRound = turnResult.nextRound;
      const expectedToken = this.roundToken += 1;
      setTimeout(() => {
        if (!this.isGameOver && this.session && expectedToken === this.roundToken) {
          this.currentRound = nextRound;
          this.syncRoundState(nextRound);
          this.inputLocked = false;
          this.updateHud();
        }
      }, this.session.roundDelayMs);
    } else {
      this.inputLocked = false;
    }
  }

  private triggerHaptic(event: HapticEvent): void {
    if (!gameRepository.getSettings().hapticsEnabled) {
      return;
    }
    this.haptics.play(event);
  }

  private isRestorableClassicSession(savedSession: ClassicSessionSnapshot): boolean {
    return savedSession.updatedAt > 0 && savedSession.mode === GameMode.CLASSIC &&
      gameRepository.hasActiveClassicSession() && !savedSession.gameOver;
  }

  private createSessionFromSnapshot(savedSession: ClassicSessionSnapshot): GameSessionState {
    return {
      mode: savedSession.mode,
      lives: savedSession.lives,
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
      isGameOver: savedSession.gameOver
    };
  }

  private restoreRoundFromSnapshot(savedSession: ClassicSessionSnapshot): GameRound {
    const roundSession: GameSessionState = this.createSessionFromSnapshot(savedSession);
    roundSession.sequenceIndex = Math.max(0, savedSession.sequenceIndex - 1);
    roundSession.turnIndex = Math.max(0, savedSession.turnIndex - 1);
    return this.gameEngine.createRound(roundSession);
  }

  build() {
    Column() {
      Blank()
        .height(18)

        Row() {
          Text(`❤️ ${this.lives}`)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#D81B60')
          Text(this.timerText === '' ? this.modeLabel : this.timerText)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor('#8B3A62')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ left: 10, right: 10 })
        .margin({ bottom: 3 })

        if (this.lifecycleBanner) {
          Text(this.lifecycleBanner)
            .fontSize(11)
            .textAlign(TextAlign.Center)
            .fontColor('#5E2740')
            .width('100%')
            .padding(6)
            .margin({ bottom: 6 })
            .backgroundColor('#FFF5FA')
        }

        Row() {
          Text(this.scoreText)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor('#8B3A62')
            .layoutWeight(1)
          Text(this.streakText)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor('#8B3A62')
            .textAlign(TextAlign.End)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        .backgroundColor('#FFF7FB')
        .borderRadius(16)

        if (this.progressText !== '') {
          Text(this.progressText)
            .fontSize(10)
            .fontColor('#9A4A67')
            .margin({ top: 3, bottom: 1 })
            .textAlign(TextAlign.Center)
            .width('100%')
        }

        Text(this.isGameOver ? 'Session complete' : 'Pick a number')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#284BFF')
          .padding({ top: 1, bottom: 2 })
          .textAlign(TextAlign.Center)
          .width('100%')

        if (!this.isGameOver) {
          QuestionMark()
          Row() {
            Button(`${this.options[0]}`)
              .width('34%')
              .height(34)
              .backgroundColor('#FFB300')
              .fontColor('#FFFFFF')
              .fontSize(14)
              .borderRadius(17)
              .margin({ right: 8 })
              .onClick(() => this.handleGuess(this.options[0]))
            Button(`${this.options[1]}`)
              .width('34%')
              .height(34)
              .backgroundColor('#FFB300')
              .fontColor('#FFFFFF')
              .fontSize(14)
              .borderRadius(17)
              .margin({ left: 8 })
              .onClick(() => this.handleGuess(this.options[1]))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 4, bottom: 28 })
        } else {
          Column() {
            Text('Game Over')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#B31252')
              .textAlign(TextAlign.Center)
              .width('100%')

            Text(this.displayMessage)
              .fontSize(12)
              .fontColor('#7A3654')
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ top: 6, bottom: 10 })

            Row() {
              Button('Replay')
                .layoutWeight(1)
                .height(34)
                .fontSize(13)
                .fontColor('#FFFFFF')
                .backgroundColor('#E58A2B')
                .borderRadius(17)
                .margin({ right: 8 })
                .onClick(() => this.startGameFromRoute())
              Button('Result')
                .layoutWeight(1)
                .height(34)
                .fontSize(13)
                .fontColor('#FFFFFF')
                .backgroundColor('#D96C8B')
                .borderRadius(17)
                .margin({ left: 8 })
                .onClick(() => {
                  const completed = gameRepository.getLastCompletedSession();
                  PageRouteTracker.setCurrentPage(PageRoutes.RESULT);
                  const params: ResultRouteParams = new ResultRouteParams();
                  params.mode = completed.mode;
                  params.summary = completed.summary;
                  AppNavigator.push(PageRoutes.RESULT, params);
                })
            }
            .width('100%')
            .margin({ top: 2 })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 12, bottom: 12 })
          .margin({ top: 8 })
          .backgroundColor('#FFF7FB')
          .borderRadius(18)
        }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.SpaceBetween)
    .height('100%')
    .padding({ left: 22, right: 22, top: 20, bottom: 26 })
    .backgroundColor('#FFE6F2')
  }
}

@Component
struct QuestionMark {
  @State rotateAngle: number = 0;
  private rotateTimer: number | null = null;

  aboutToAppear() {
    this.startRotateAnimation();
  }

  aboutToDisappear() {
    this.stopRotateAnimation();
  }

  startRotateAnimation() {
    this.stopRotateAnimation();
    this.rotateTimer = setInterval(() => {
      this.rotateAngle += CommonConstants.ROTATE_STEP;
    }, CommonConstants.ROTATE_INTERVAL_MS);
  }

  stopRotateAnimation() {
    if (this.rotateTimer) {
      clearInterval(this.rotateTimer);
      this.rotateTimer = null;
    }
  }

  build() {
    Text('❓')
      .fontSize(42)
      .padding({ top: 2, bottom: 2 })
      .alignSelf(ItemAlign.Center)
      .fontColor('#E53935')
      .rotate({ angle: this.rotateAngle })
      .animation({ curve: Curve.Linear, playMode: PlayMode.Normal })
  }
}
