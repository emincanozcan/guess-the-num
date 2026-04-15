import { gameRepository } from '../../data/GameRepository';

class GlobalDataStore {
  message: string = '';

  constructor() {
    gameRepository.initialize();
  }

  get userLives(): number {
    return gameRepository.getClassicLives();
  }

  set userLives(value: number) {
    gameRepository.setClassicLives(value);
  }

  get isGameOver(): boolean {
    return gameRepository.getGameOver();
  }

  set isGameOver(value: boolean) {
    gameRepository.setGameOver(value);
  }
}

export const globalMessageStore = new GlobalDataStore();
