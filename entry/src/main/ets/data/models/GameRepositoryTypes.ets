import { GameMode } from '../../game/models/GameMode';

export interface ClassicSessionSnapshot {
  mode: GameMode;
  lives: number;
  gameOver: boolean;
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
  updatedAt: number;
  message: string;
}

export interface GameSettings {
  backgroundPenaltyEnabled: boolean;
  backgroundPolicy: BackgroundPolicy;
  timedBackgroundPolicy: TimedBackgroundPolicy;
  preferredMode: GameMode;
  keepLifecycleSnapshots: boolean;
  hapticsEnabled: boolean;
  dailyReminderEnabled: boolean;
  dailyReminderHour: number;
  dailyReminderMinute: number;
  dailyReminderStatus: ReminderScheduleStatus;
  dailyReminderToken: string;
  dailyReminderUpdatedAt: number;
}

export interface GameSettingsUpdate {
  backgroundPenaltyEnabled?: boolean;
  backgroundPolicy?: BackgroundPolicy;
  timedBackgroundPolicy?: TimedBackgroundPolicy;
  preferredMode?: GameMode;
  keepLifecycleSnapshots?: boolean;
  hapticsEnabled?: boolean;
  dailyReminderEnabled?: boolean;
  dailyReminderHour?: number;
  dailyReminderMinute?: number;
  dailyReminderStatus?: ReminderScheduleStatus;
  dailyReminderToken?: string;
  dailyReminderUpdatedAt?: number;
}

export type BackgroundPolicy = 'penalize' | 'log-only';

export type TimedBackgroundPolicy = 'pause' | 'log-only';

export type ReminderScheduleStatus = 'idle' | 'scheduled' | 'cancelled' | 'unsupported' | 'failed';

export interface PlayerStats {
  totalSessions: number;
  completedSessions: number;
  totalCorrect: number;
  totalWrong: number;
  bestScore: number;
  bestStreak: number;
  longestRun: number;
  longestStreak: number;
  bestTimedScore: number;
  backgroundPenalties: number;
  backgroundLosses: number;
  lastPlayedAt: number;
}

export interface AchievementProgress {
  id: string;
  title: string;
  description: string;
  unlocked: boolean;
  progress: number;
  target: number;
  unlockedAt: number;
}

export interface SessionHistoryEntry {
  sessionId: string;
  mode: GameMode;
  reason: string;
  summary: string;
  score: number;
  livesRemaining: number;
  correctCount: number;
  wrongCount: number;
  bestStreak: number;
  completedRounds: number;
  completedAt: number;
}

export interface LastCompletedSessionSummary {
  sessionId: string;
  mode: GameMode;
  reason: string;
  summary: string;
  score: number;
  livesRemaining: number;
  correctCount: number;
  wrongCount: number;
  bestStreak: number;
  completedRounds: number;
  completedAt: number;
}

export interface LifecycleSnapshot {
  capturedAt: number;
  entries: LifecycleEntry[];
}

export interface LifecycleEntry {
  capturedAt: number;
  stage: string;
  message: string;
}

export interface GameProfile {
  lives: number;
  gameOver: boolean;
  classicSessionActive: boolean;
  onboardingCompleted: boolean;
  lifecycleBanner: string;
  pendingLifecycleBanner: string;
  timedSessionBackgroundStartedAt: number;
  stats: PlayerStats;
  lastSession: ClassicSessionSnapshot;
  lastCompletedSession: LastCompletedSessionSummary;
}

export interface DurableGameRepositoryState {
  schemaVersion: number;
  profile: GameProfile;
  settings: GameSettings;
  history: SessionHistoryEntry[];
  achievements: AchievementProgress[];
  lifecycleSnapshots: LifecycleSnapshot[];
}

export interface BackupProfile {
  lives: number;
  gameOver: boolean;
  classicSessionActive: boolean;
  onboardingCompleted: boolean;
  stats: PlayerStats;
  lastSession: ClassicSessionSnapshot;
  lastCompletedSession: LastCompletedSessionSummary;
}

export interface BackupSettings {
  backgroundPenaltyEnabled: boolean;
  backgroundPolicy: BackgroundPolicy;
  timedBackgroundPolicy: TimedBackgroundPolicy;
  preferredMode: GameMode;
  keepLifecycleSnapshots: boolean;
  hapticsEnabled: boolean;
  dailyReminderEnabled: boolean;
  dailyReminderHour: number;
  dailyReminderMinute: number;
}

export interface DurableBackupRepositoryState {
  schemaVersion: number;
  profile: BackupProfile;
  settings: BackupSettings;
  history: SessionHistoryEntry[];
  achievements: AchievementProgress[];
}

export interface GameRepositoryBackupPayload {
  schemaVersion: number;
  exportedAt: number;
  repository: DurableBackupRepositoryState;
}
