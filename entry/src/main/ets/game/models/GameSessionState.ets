import { GameMode } from './GameMode';

export interface GameSessionState {
  mode: GameMode;
  lives: number;
  score: number;
  streak: number;
  bestStreak: number;
  correctCount: number;
  wrongCount: number;
  completedRounds: number;
  sequenceIndex: number;
  turnIndex: number;
  roundDelayMs: number;
  timeLimitMs: number;
  remainingTimeMs: number;
  isGameOver: boolean;
}
