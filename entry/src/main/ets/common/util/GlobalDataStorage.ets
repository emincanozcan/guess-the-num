import { gameRepository } from '../../data/GameRepository';

// GlobalDataStore manages global game data such as user lives and game over state
class GlobalDataStore {
  // A message string that can be used throughout the game
  message: string = '';

  constructor() {
    gameRepository.initialize();
  }

  // Getter for userLives; retrieves from persistent storage or defaults to 3
  get userLives(): number {
    return gameRepository.getClassicLives();
  }

  // Setter for userLives; updates the persistent storage
  set userLives(value: number) {
    gameRepository.setClassicLives(value);
  }

  // Getter for isGameOver; retrieves from persistent storage or defaults to false
  get isGameOver(): boolean {
    return gameRepository.getGameOver();
  }

  // Setter for isGameOver; updates the persistent storage
  set isGameOver(value: boolean) {
    gameRepository.setGameOver(value);
  }
}

// Export a single instance of GlobalDataStore for global use
export const globalMessageStore = new GlobalDataStore();
