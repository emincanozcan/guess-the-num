import { GameMode } from './GameMode';

export enum GameResultReason {
  OUT_OF_LIVES = 'out_of_lives',
  TIME_EXPIRED = 'time_expired',
  TARGET_STREAK_REACHED = 'target_streak_reached'
}

export interface GameResult {
  mode: GameMode;
  reason: GameResultReason;
  finalScore: number;
  livesRemaining: number;
  correctCount: number;
  wrongCount: number;
  bestStreak: number;
  completedRounds: number;
  completedAt: number;
}
