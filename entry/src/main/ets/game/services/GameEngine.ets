import CommonConstants from '../../common/constants/CommonConstants';
import { GameMode } from '../models/GameMode';
import { GameResult, GameResultReason } from '../models/GameResult';
import { GameRound } from '../models/GameRound';
import { GameSessionState } from '../models/GameSessionState';

export interface GameModeConfig {
  startingLives: number;
  roundDelayMs: number;
  timeLimitMs: number;
  scorePerCorrect: number;
  scorePerWrong: number;
  streakBonus: number;
  targetStreak: number;
}

export interface GameEngineConfig {
  classic?: Partial<GameModeConfig>;
  timed?: Partial<GameModeConfig>;
  streak?: Partial<GameModeConfig>;
}

export interface GameSessionBundle {
  session: GameSessionState;
  round: GameRound;
}

export interface GameTurnResult {
  session: GameSessionState;
  isCorrect: boolean;
  message: string;
  nextRound?: GameRound;
  result?: GameResult;
}

export class GameEngine {
  private readonly numberPool: number[] = [
    1, 2, 3, 4, 5, 1, 2, 3, 4, 5,
    1, 2, 3, 4, 5, 1, 2, 3, 4, 5,
    1, 2, 3, 4, 5, 1, 2, 3, 4, 5
  ];

  private readonly classicConfig: GameModeConfig;
  private readonly timedConfig: GameModeConfig;
  private readonly streakConfig: GameModeConfig;

  constructor(config: GameEngineConfig = {}) {
    this.classicConfig = this.mergeConfig({
      startingLives: CommonConstants.DEFAULT_LIVES,
      roundDelayMs: CommonConstants.DEFAULT_ROUND_DELAY_MS,
      timeLimitMs: 0,
      scorePerCorrect: 1,
      scorePerWrong: 0,
      streakBonus: 0,
      targetStreak: 0
    }, config.classic);
    this.timedConfig = this.mergeConfig({
      startingLives: CommonConstants.DEFAULT_LIVES,
      roundDelayMs: CommonConstants.DEFAULT_ROUND_DELAY_MS,
      timeLimitMs: CommonConstants.DEFAULT_TIMED_LIMIT_MS,
      scorePerCorrect: 2,
      scorePerWrong: 0,
      streakBonus: 1,
      targetStreak: 0
    }, config.timed);
    this.streakConfig = this.mergeConfig({
      startingLives: CommonConstants.DEFAULT_LIVES,
      roundDelayMs: CommonConstants.DEFAULT_ROUND_DELAY_MS,
      timeLimitMs: 0,
      scorePerCorrect: 1,
      scorePerWrong: 0,
      streakBonus: 2,
      targetStreak: CommonConstants.DEFAULT_STREAK_TARGET
    }, config.streak);
  }

  createSession(mode: GameMode = GameMode.CLASSIC): GameSessionBundle {
    const session: GameSessionState = this.buildSession(mode);
    return {
      session,
      round: this.createRound(session)
    };
  }

  createRound(session: GameSessionState): GameRound {
    const options = this.buildOptions(session.sequenceIndex);
    const secretNumber = options[session.turnIndex % options.length];
    const round: GameRound = {
      roundId: session.completedRounds + 1,
      mode: session.mode,
      options,
      secretNumber,
      generatedAt: new Date().getTime(),
      timeLimitMs: session.timeLimitMs
    };

    session.sequenceIndex = (session.sequenceIndex + 1) % this.numberPool.length;
    session.turnIndex += 1;

    return round;
  }

  submitGuess(session: GameSessionState, round: GameRound, guess: number): GameTurnResult {
    const isCorrect = guess === round.secretNumber;
    const modeConfig = this.getModeConfig(session.mode);

    session.completedRounds += 1;

    if (isCorrect) {
      session.correctCount += 1;
      session.streak += 1;
      session.bestStreak = Math.max(session.bestStreak, session.streak);
      session.score += modeConfig.scorePerCorrect + modeConfig.streakBonus * (session.streak > 1 ? 1 : 0);
    } else {
      session.wrongCount += 1;
      session.streak = 0;
      session.lives = Math.max(0, session.lives - 1);
      session.score = Math.max(0, session.score + modeConfig.scorePerWrong);
    }

    if (session.mode === GameMode.STREAK && modeConfig.targetStreak > 0 && session.streak >= modeConfig.targetStreak) {
      session.isGameOver = true;
      return {
        session,
        isCorrect,
        message: 'Streak complete!',
        result: this.buildResult(session, GameResultReason.TARGET_STREAK_REACHED)
      };
    }

    if (session.lives <= 0) {
      session.isGameOver = true;
      return {
        session,
        isCorrect,
        message: 'Game over!',
        result: this.buildResult(session, GameResultReason.OUT_OF_LIVES)
      };
    }

    return {
      session,
      isCorrect,
      message: isCorrect ? 'Correct!' : `Wrong! It was ${round.secretNumber}`,
      nextRound: this.createRound(session)
    };
  }

  advanceTimer(session: GameSessionState, elapsedMs: number): GameResult | undefined {
    if (session.mode !== GameMode.TIMED || session.isGameOver) {
      return undefined;
    }

    session.remainingTimeMs = Math.max(0, session.remainingTimeMs - elapsedMs);

    if (session.remainingTimeMs === 0) {
      session.isGameOver = true;
      return this.buildResult(session, GameResultReason.TIME_EXPIRED);
    }

    return undefined;
  }

  getModeConfig(mode: GameMode): GameModeConfig {
    switch (mode) {
      case GameMode.TIMED:
        return this.timedConfig;
      case GameMode.STREAK:
        return this.streakConfig;
      case GameMode.CLASSIC:
      default:
        return this.classicConfig;
    }
  }

  private mergeConfig(base: GameModeConfig, overrides?: Partial<GameModeConfig>): GameModeConfig {
    if (!overrides) {
      return base;
    }

    return {
      startingLives: overrides.startingLives ?? base.startingLives,
      roundDelayMs: overrides.roundDelayMs ?? base.roundDelayMs,
      timeLimitMs: overrides.timeLimitMs ?? base.timeLimitMs,
      scorePerCorrect: overrides.scorePerCorrect ?? base.scorePerCorrect,
      scorePerWrong: overrides.scorePerWrong ?? base.scorePerWrong,
      streakBonus: overrides.streakBonus ?? base.streakBonus,
      targetStreak: overrides.targetStreak ?? base.targetStreak
    };
  }

  private buildSession(mode: GameMode): GameSessionState {
    const config = this.getModeConfig(mode);
    return {
      mode,
      lives: config.startingLives,
      score: 0,
      streak: 0,
      bestStreak: 0,
      correctCount: 0,
      wrongCount: 0,
      completedRounds: 0,
      sequenceIndex: 0,
      turnIndex: 0,
      roundDelayMs: config.roundDelayMs,
      timeLimitMs: config.timeLimitMs,
      remainingTimeMs: config.timeLimitMs,
      isGameOver: false
    };
  }

  private buildOptions(sequenceIndex: number): number[] {
    const first = this.numberPool[sequenceIndex % this.numberPool.length];
    const second = this.numberPool[(sequenceIndex + 1) % this.numberPool.length];
    return [first, second];
  }

  private buildResult(session: GameSessionState, reason: GameResultReason): GameResult {
    return {
      mode: session.mode,
      reason,
      finalScore: session.score,
      livesRemaining: session.lives,
      correctCount: session.correctCount,
      wrongCount: session.wrongCount,
      bestStreak: session.bestStreak,
      completedRounds: session.completedRounds,
      completedAt: new Date().getTime()
    };
  }
}
