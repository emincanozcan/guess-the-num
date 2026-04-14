import CommonConstants from '../common/constants/CommonConstants';
import { GameMode } from '../game/models/GameMode';
import {
  AchievementProgress,
  BackgroundPolicy,
  GameSettings,
  PlayerStats,
  ReminderScheduleStatus,
  SessionHistoryEntry,
  TimedBackgroundPolicy,
  LifecycleEntry
} from './models/GameRepositoryTypes';

export function sanitizeLives(value: number | undefined): number {
  if (value === undefined || value === null || Number.isNaN(value)) {
    return CommonConstants.DEFAULT_LIVES;
  }
  return Math.max(0, Math.floor(value));
}

export function sanitizeCount(value: number | undefined): number {
  if (value === undefined || value === null || Number.isNaN(value)) {
    return 0;
  }
  return Math.max(0, Math.floor(value));
}

export function sanitizeHour(value: number): number {
  if (value === undefined || value === null || Number.isNaN(value)) {
    return 20;
  }
  return Math.max(0, Math.min(23, Math.floor(value)));
}

export function sanitizeMinute(value: number): number {
  if (value === undefined || value === null || Number.isNaN(value)) {
    return 0;
  }
  return Math.max(0, Math.min(59, Math.floor(value)));
}

export function sanitizeReminderStatus(value: string): ReminderScheduleStatus {
  if (value === 'scheduled' || value === 'cancelled' || value === 'unsupported' || value === 'failed') {
    return value;
  }
  return 'idle';
}

export function sanitizeReminderToken(value: string | undefined): string {
  if (!value) {
    return '';
  }
  return value;
}

export function createStats(totalSessions: number, completedSessions: number, totalCorrect: number, totalWrong: number,
  bestScore: number, bestStreak: number, longestRun: number, longestStreak: number, bestTimedScore: number,
  backgroundPenalties: number, backgroundLosses: number, lastPlayedAt: number): PlayerStats {
  return {
    totalSessions: totalSessions,
    completedSessions: completedSessions,
    totalCorrect: totalCorrect,
    totalWrong: totalWrong,
    bestScore: bestScore,
    bestStreak: bestStreak,
    longestRun: longestRun,
    longestStreak: longestStreak,
    bestTimedScore: bestTimedScore,
    backgroundPenalties: backgroundPenalties,
    backgroundLosses: backgroundLosses,
    lastPlayedAt: lastPlayedAt
  };
}

export function copyStats(stats: PlayerStats): PlayerStats {
  return createStats(stats.totalSessions, stats.completedSessions, stats.totalCorrect, stats.totalWrong,
    stats.bestScore, stats.bestStreak, stats.longestRun, stats.longestStreak, stats.bestTimedScore,
    stats.backgroundPenalties, stats.backgroundLosses, stats.lastPlayedAt);
}

export function createSettings(backgroundPenaltyEnabled: boolean, backgroundPolicy: BackgroundPolicy,
  timedBackgroundPolicy: TimedBackgroundPolicy, preferredMode: GameMode, keepLifecycleSnapshots: boolean,
  hapticsEnabled: boolean, dailyReminderEnabled: boolean, dailyReminderHour: number, dailyReminderMinute: number,
  dailyReminderStatus: ReminderScheduleStatus, dailyReminderToken: string, dailyReminderUpdatedAt: number): GameSettings {
  return {
    backgroundPenaltyEnabled: backgroundPenaltyEnabled,
    backgroundPolicy: backgroundPolicy,
    timedBackgroundPolicy: timedBackgroundPolicy,
    preferredMode: preferredMode,
    keepLifecycleSnapshots: keepLifecycleSnapshots,
    hapticsEnabled: hapticsEnabled,
    dailyReminderEnabled: dailyReminderEnabled,
    dailyReminderHour: sanitizeHour(dailyReminderHour),
    dailyReminderMinute: sanitizeMinute(dailyReminderMinute),
    dailyReminderStatus: sanitizeReminderStatus(dailyReminderStatus),
    dailyReminderToken: sanitizeReminderToken(dailyReminderToken),
    dailyReminderUpdatedAt: sanitizeCount(dailyReminderUpdatedAt)
  };
}

export function copySettings(settings: GameSettings): GameSettings {
  return createSettings(settings.backgroundPenaltyEnabled, settings.backgroundPolicy, settings.timedBackgroundPolicy,
    settings.preferredMode, settings.keepLifecycleSnapshots, settings.hapticsEnabled, settings.dailyReminderEnabled,
    settings.dailyReminderHour, settings.dailyReminderMinute, settings.dailyReminderStatus,
    settings.dailyReminderToken, settings.dailyReminderUpdatedAt);
}

export function createLifecycleEntry(capturedAt: number, stage: string, message: string): LifecycleEntry {
  return { capturedAt: capturedAt, stage: stage, message: message };
}

export function copyLifecycleEntries(entries: LifecycleEntry[]): LifecycleEntry[] {
  const copies: LifecycleEntry[] = [];
  for (const entry of entries) {
    copies.push(createLifecycleEntry(entry.capturedAt, entry.stage, entry.message));
  }
  return copies;
}

export function createAchievement(id: string, title: string, description: string, unlocked: boolean,
  progress: number, target: number, unlockedAt: number): AchievementProgress {
  return {
    id: id,
    title: title,
    description: description,
    unlocked: unlocked,
    progress: progress,
    target: target,
    unlockedAt: unlockedAt
  };
}

export function createDefaultAchievements(): AchievementProgress[] {
  return [
    createAchievement('first-session', 'First Session', 'Complete your first recorded session.', false, 0, 1, 0),
    createAchievement('steady-player', 'Steady Player', 'Complete three sessions.', false, 0, 3, 0),
    createAchievement('streak-builder', 'Streak Builder', 'Reach a best streak of five.', false, 0, 5, 0),
    createAchievement('score-keeper', 'Score Keeper', 'Reach a score of ten.', false, 0, 10, 0)
  ];
}

export function createDefaultStats(): PlayerStats {
  return createStats(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
}

export function createHistoryEntry(sessionId: string, mode: GameMode, reason: string, summary: string, score: number,
  livesRemaining: number, correctCount: number, wrongCount: number, bestStreak: number,
  completedRounds: number, completedAt: number): SessionHistoryEntry {
  return {
    sessionId: sessionId,
    mode: mode,
    reason: reason,
    summary: summary,
    score: score,
    livesRemaining: livesRemaining,
    correctCount: correctCount,
    wrongCount: wrongCount,
    bestStreak: bestStreak,
    completedRounds: completedRounds,
    completedAt: completedAt
  };
}

export function computeAchievementUnlocked(id: string, stats: PlayerStats, currentUnlocked: boolean): boolean {
  if (currentUnlocked) {
    return true;
  }

  switch (id) {
    case 'first-session':
      return stats.totalSessions >= 1;
    case 'steady-player':
      return stats.completedSessions >= 3;
    case 'streak-builder':
      return stats.bestStreak >= 5;
    case 'score-keeper':
      return stats.bestScore >= 10;
    default:
      return currentUnlocked;
  }
}

export function computeAchievementProgress(id: string, stats: PlayerStats): number {
  switch (id) {
    case 'first-session':
      return Math.min(stats.totalSessions, 1);
    case 'steady-player':
      return Math.min(stats.completedSessions, 3);
    case 'streak-builder':
      return Math.min(stats.bestStreak, 5);
    case 'score-keeper':
      return Math.min(stats.bestScore, 10);
    default:
      return 0;
  }
}
