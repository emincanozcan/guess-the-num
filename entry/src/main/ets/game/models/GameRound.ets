import { GameMode } from './GameMode';

export interface GameRound {
  roundId: number;
  mode: GameMode;
  options: number[];
  secretNumber: number;
  generatedAt: number;
  timeLimitMs: number;
}
