import CommonConstants from "../constants/CommonConstants";

// GlobalDataStore class manages global game data such as user lives and game over state
class GlobalDataStore {
  // A message string that can be used throughout the game
  message: string = '';

  constructor() {
    // Initialize user lives to 3 and gameOver flag to false in persistent storage
    AppStorage.set<number>('userLives', CommonConstants.DEFAULT_LIVES);
    AppStorage.set<boolean>('gameOver', false);
  }

  // Getter for userLives; retrieves from persistent storage or defaults to 3
  get userLives(): number {
    return AppStorage.get<number>('userLives') ?? CommonConstants.DEFAULT_LIVES;
  }

  // Setter for userLives; updates the persistent storage
  set userLives(value: number) {
    AppStorage.set<number>('userLives', value);
  }

  // Getter for isGameOver; retrieves from persistent storage or defaults to false
  get isGameOver(): boolean {
    return AppStorage.get<boolean>('gameOver') ?? false;
  }

  // Setter for isGameOver; updates the persistent storage
  set isGameOver(value: boolean) {
    AppStorage.set<boolean>('gameOver', value);
  }
}

// Export a single instance of GlobalDataStore for global use
export const GlobalMessageStore = new GlobalDataStore();