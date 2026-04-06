export default class CommonConstants {
  // Game-related constants
  // Default user lives
  static DEFAULT_LIVES: number = 3;
  static DEFAULT_GAME_MODE: string = 'classic';
  static DEFAULT_ROUND_DELAY_MS: number = 1000;
  static DEFAULT_TIMED_LIMIT_MS: number = 30000;
  static DEFAULT_STREAK_TARGET: number = 5;
  // Maximum number of logs to keep
  static MAX_LOGS: number = 20;
  // Default game over message
  static GAME_OVER_MESSAGE: string = 'Game Over';
  // Animation / rotation
  static ROTATE_STEP = 30;
  // Degrees
  static ROTATE_INTERVAL_MS = 100;
  // Milliseconds

  // Screen size
  static FULL_WIDTH: string = '100%';
  static FULL_HEIGHT: string = '100%';
}
