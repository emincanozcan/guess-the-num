import CommonConstants from '../common/constants/CommonConstants';
import { GameMode } from '../game/models/GameMode';
import { GameResult, GameResultReason } from '../game/models/GameResult';
import { GameSessionState } from '../game/models/GameSessionState';
import {
  computeAchievementProgress,
  computeAchievementUnlocked,
  copyLifecycleEntries,
  createAchievement,
  createDefaultAchievements,
  createDefaultStats,
  createHistoryEntry,
  createSettings,
  createStats,
  sanitizeCount,
  sanitizeHour,
  sanitizeLives,
  sanitizeMinute,
  sanitizeReminderStatus,
  sanitizeReminderToken
} from './GameRepositoryHelpers';
import {
  AchievementProgress,
  BackgroundPolicy,
  ClassicSessionSnapshot,
  DurableGameRepositoryState,
  GameSettings,
  GameSettingsUpdate,
  LastCompletedSessionSummary,
  LifecycleEntry,
  LifecycleSnapshot,
  PlayerStats,
  ReminderScheduleStatus,
  SessionHistoryEntry,
  TimedBackgroundPolicy
} from './models/GameRepositoryTypes';

export abstract class GameRepositoryStateSupport {
  protected static readonly SCHEMA_VERSION = 1;

  protected normalizeState(state: DurableGameRepositoryState): DurableGameRepositoryState {
    const normalized = this.createDefaultState();
    normalized.schemaVersion = GameRepositoryStateSupport.SCHEMA_VERSION;
    normalized.profile.lives = sanitizeLives(state?.profile?.lives ?? CommonConstants.DEFAULT_LIVES);
    normalized.profile.gameOver = state?.profile?.gameOver ?? false;
    normalized.profile.classicSessionActive = state?.profile?.classicSessionActive ?? false;
    normalized.profile.onboardingCompleted = state?.profile?.onboardingCompleted ?? false;
    normalized.profile.lifecycleBanner = state?.profile?.lifecycleBanner ?? '';
    normalized.profile.pendingLifecycleBanner = state?.profile?.pendingLifecycleBanner ?? '';
    normalized.profile.timedSessionBackgroundStartedAt = sanitizeCount(state?.profile?.timedSessionBackgroundStartedAt);
    normalized.profile.stats = createStats(
      sanitizeCount(state?.profile?.stats?.totalSessions), sanitizeCount(state?.profile?.stats?.completedSessions),
      sanitizeCount(state?.profile?.stats?.totalCorrect), sanitizeCount(state?.profile?.stats?.totalWrong),
      sanitizeCount(state?.profile?.stats?.bestScore), sanitizeCount(state?.profile?.stats?.bestStreak),
      sanitizeCount(state?.profile?.stats?.longestRun), sanitizeCount(state?.profile?.stats?.longestStreak ?? state?.profile?.stats?.bestStreak),
      sanitizeCount(state?.profile?.stats?.bestTimedScore), sanitizeCount(state?.profile?.stats?.backgroundPenalties),
      sanitizeCount(state?.profile?.stats?.backgroundLosses), sanitizeCount(state?.profile?.stats?.lastPlayedAt)
    );
    normalized.profile.lastSession = this.normalizeSessionSnapshot(state?.profile?.lastSession, normalized.profile.lives, normalized.profile.gameOver);
    normalized.profile.lastCompletedSession = this.normalizeCompletedSessionSummary(state?.profile?.lastCompletedSession);
    normalized.settings = this.normalizeSettings(state?.settings);
    normalized.history = this.normalizeHistory(state?.history);
    normalized.achievements = this.normalizeAchievements(state?.achievements, normalized.profile.stats);
    normalized.lifecycleSnapshots = this.normalizeSnapshots(state?.lifecycleSnapshots);
    return normalized;
  }

  protected mergeSettings(current: GameSettings, updates: GameSettingsUpdate): GameSettings {
    return createSettings(
      updates.backgroundPenaltyEnabled ?? current.backgroundPenaltyEnabled,
      updates.backgroundPolicy ?? current.backgroundPolicy,
      updates.timedBackgroundPolicy ?? current.timedBackgroundPolicy,
      updates.preferredMode ?? current.preferredMode,
      updates.keepLifecycleSnapshots ?? current.keepLifecycleSnapshots,
      updates.hapticsEnabled ?? current.hapticsEnabled,
      updates.dailyReminderEnabled ?? current.dailyReminderEnabled,
      updates.dailyReminderHour ?? current.dailyReminderHour,
      updates.dailyReminderMinute ?? current.dailyReminderMinute,
      updates.dailyReminderStatus ?? current.dailyReminderStatus,
      updates.dailyReminderToken ?? current.dailyReminderToken,
      updates.dailyReminderUpdatedAt ?? current.dailyReminderUpdatedAt
    );
  }

  protected normalizeProgressMessage(message: string, gameOver: boolean): string {
    if (gameOver) {
      return message;
    }
    if (message === 'Correct!' || message.startsWith('Wrong! It was ')) {
      return '';
    }
    return message;
  }

  protected buildEmptySessionSnapshot(lives: number, gameOver: boolean): ClassicSessionSnapshot {
    return {
      mode: GameMode.CLASSIC,
      lives,
      gameOver,
      score: 0,
      streak: 0,
      bestStreak: 0,
      correctCount: 0,
      wrongCount: 0,
      completedRounds: 0,
      sequenceIndex: 0,
      turnIndex: 0,
      roundDelayMs: CommonConstants.DEFAULT_ROUND_DELAY_MS,
      timeLimitMs: 0,
      remainingTimeMs: 0,
      updatedAt: 0,
      message: ''
    };
  }

  protected buildEmptyCompletedSessionSummary(): LastCompletedSessionSummary {
    return {
      sessionId: '',
      mode: GameMode.CLASSIC,
      reason: GameResultReason.OUT_OF_LIVES,
      summary: '',
      score: 0,
      livesRemaining: CommonConstants.DEFAULT_LIVES,
      correctCount: 0,
      wrongCount: 0,
      bestStreak: 0,
      completedRounds: 0,
      completedAt: 0
    };
  }

  protected normalizeCompletedSessionSummary(summary?: LastCompletedSessionSummary): LastCompletedSessionSummary {
    if (!summary) {
      return this.buildEmptyCompletedSessionSummary();
    }
    return {
      sessionId: summary.sessionId ?? this.makeSessionId(),
      mode: summary.mode ?? GameMode.CLASSIC,
      reason: summary.reason ?? GameResultReason.OUT_OF_LIVES,
      summary: summary.summary ?? '',
      score: sanitizeCount(summary.score),
      livesRemaining: sanitizeLives(summary.livesRemaining),
      correctCount: sanitizeCount(summary.correctCount),
      wrongCount: sanitizeCount(summary.wrongCount),
      bestStreak: sanitizeCount(summary.bestStreak),
      completedRounds: sanitizeCount(summary.completedRounds),
      completedAt: sanitizeCount(summary.completedAt)
    };
  }

  protected touchAchievementProgress(state: DurableGameRepositoryState, session: GameSessionState, result?: GameResult): void {
    state.achievements = this.applyAchievementProgress(state.achievements, state.profile.stats);
    if (result) {
      state.profile.stats.bestScore = Math.max(state.profile.stats.bestScore, result.finalScore);
      state.profile.stats.bestStreak = Math.max(state.profile.stats.bestStreak, result.bestStreak);
    } else {
      state.profile.stats.bestStreak = Math.max(state.profile.stats.bestStreak, session.bestStreak);
    }
  }

  protected createDefaultState(): DurableGameRepositoryState {
    return {
      schemaVersion: GameRepositoryStateSupport.SCHEMA_VERSION,
      profile: {
        lives: CommonConstants.DEFAULT_LIVES,
        gameOver: false,
        classicSessionActive: false,
        onboardingCompleted: false,
        lifecycleBanner: '',
        pendingLifecycleBanner: '',
        timedSessionBackgroundStartedAt: 0,
        stats: createDefaultStats(),
        lastSession: this.buildEmptySessionSnapshot(CommonConstants.DEFAULT_LIVES, false),
        lastCompletedSession: this.buildEmptyCompletedSessionSummary()
      },
      settings: {
        backgroundPenaltyEnabled: true,
        backgroundPolicy: 'penalize' as BackgroundPolicy,
        timedBackgroundPolicy: 'pause' as TimedBackgroundPolicy,
        preferredMode: GameMode.CLASSIC,
        keepLifecycleSnapshots: true,
        hapticsEnabled: true,
        dailyReminderEnabled: false,
        dailyReminderHour: 20,
        dailyReminderMinute: 0,
        dailyReminderStatus: 'idle' as ReminderScheduleStatus,
        dailyReminderToken: '',
        dailyReminderUpdatedAt: 0
      },
      history: [],
      achievements: createDefaultAchievements(),
      lifecycleSnapshots: []
    };
  }

  protected makeSessionId(): string {
    return `session-${Date.now()}-${Math.floor(Math.random() * 10000)}`;
  }

  private normalizeSettings(settings?: GameSettings): GameSettings {
    const defaults = this.createDefaultState().settings;
    return {
      backgroundPenaltyEnabled: settings?.backgroundPenaltyEnabled ?? defaults.backgroundPenaltyEnabled,
      backgroundPolicy: settings?.backgroundPolicy ?? defaults.backgroundPolicy,
      timedBackgroundPolicy: settings?.timedBackgroundPolicy ?? defaults.timedBackgroundPolicy,
      preferredMode: settings?.preferredMode ?? defaults.preferredMode,
      keepLifecycleSnapshots: settings?.keepLifecycleSnapshots ?? defaults.keepLifecycleSnapshots,
      hapticsEnabled: settings?.hapticsEnabled ?? defaults.hapticsEnabled,
      dailyReminderEnabled: settings?.dailyReminderEnabled ?? defaults.dailyReminderEnabled,
      dailyReminderHour: sanitizeHour(settings?.dailyReminderHour ?? defaults.dailyReminderHour),
      dailyReminderMinute: sanitizeMinute(settings?.dailyReminderMinute ?? defaults.dailyReminderMinute),
      dailyReminderStatus: sanitizeReminderStatus(settings?.dailyReminderStatus ?? defaults.dailyReminderStatus),
      dailyReminderToken: sanitizeReminderToken(settings?.dailyReminderToken ?? defaults.dailyReminderToken),
      dailyReminderUpdatedAt: sanitizeCount(settings?.dailyReminderUpdatedAt ?? defaults.dailyReminderUpdatedAt)
    };
  }

  protected normalizeHistory(history?: SessionHistoryEntry[]): SessionHistoryEntry[] {
    const result: SessionHistoryEntry[] = [];
    if (!history) {
      return result;
    }
    for (const item of history) {
      result.push(createHistoryEntry(
        item?.sessionId ?? this.makeSessionId(), item?.mode ?? GameMode.CLASSIC,
        item?.reason ?? GameResultReason.OUT_OF_LIVES, item?.summary ?? 'Saved session',
        sanitizeCount(item?.score), sanitizeLives(item?.livesRemaining ?? CommonConstants.DEFAULT_LIVES),
        sanitizeCount(item?.correctCount), sanitizeCount(item?.wrongCount),
        sanitizeCount(item?.bestStreak), sanitizeCount(item?.completedRounds), sanitizeCount(item?.completedAt)
      ));
    }
    return result;
  }

  protected normalizeAchievements(achievements: AchievementProgress[] | undefined, stats: PlayerStats): AchievementProgress[] {
    const defaults = createDefaultAchievements();
    if (!achievements || achievements.length === 0) {
      return this.applyAchievementProgress(defaults, stats);
    }
    return this.applyAchievementProgress(achievements, stats);
  }

  private applyAchievementProgress(achievements: AchievementProgress[], stats: PlayerStats): AchievementProgress[] {
    const normalized: AchievementProgress[] = [];
    for (const achievement of achievements) {
      const unlocked = computeAchievementUnlocked(achievement.id, stats, achievement.unlocked);
      normalized.push(createAchievement(
        achievement.id, achievement.title, achievement.description, unlocked,
        computeAchievementProgress(achievement.id, stats), achievement.target,
        unlocked && achievement.unlockedAt === 0 ? Date.now() : achievement.unlockedAt
      ));
    }
    return normalized;
  }

  private normalizeSnapshots(snapshots?: LifecycleSnapshot[]): LifecycleSnapshot[] {
    const result: LifecycleSnapshot[] = [];
    if (!snapshots) {
      return result;
    }
    for (const snapshot of snapshots) {
      result.push({ capturedAt: sanitizeCount(snapshot?.capturedAt), entries: this.normalizeLifecycleEntries(snapshot?.entries) });
    }
    return result;
  }

  private normalizeLifecycleEntries(entries?: LifecycleEntry[]): LifecycleEntry[] {
    if (entries && entries.length > 0) {
      return copyLifecycleEntries(entries);
    }
    return [];
  }

  protected normalizeSessionSnapshot(snapshot: ClassicSessionSnapshot | undefined, lives: number, gameOver: boolean): ClassicSessionSnapshot {
    const message = this.normalizeProgressMessage(snapshot?.message ?? '', gameOver);
    return {
      mode: snapshot?.mode ?? GameMode.CLASSIC,
      lives: sanitizeLives(snapshot?.lives ?? lives),
      gameOver: snapshot?.gameOver ?? gameOver,
      score: sanitizeCount(snapshot?.score),
      streak: sanitizeCount(snapshot?.streak),
      bestStreak: sanitizeCount(snapshot?.bestStreak),
      correctCount: sanitizeCount(snapshot?.correctCount),
      wrongCount: sanitizeCount(snapshot?.wrongCount),
      completedRounds: sanitizeCount(snapshot?.completedRounds),
      sequenceIndex: sanitizeCount(snapshot?.sequenceIndex),
      turnIndex: sanitizeCount(snapshot?.turnIndex),
      roundDelayMs: sanitizeCount(snapshot?.roundDelayMs ?? CommonConstants.DEFAULT_ROUND_DELAY_MS),
      timeLimitMs: sanitizeCount(snapshot?.timeLimitMs),
      remainingTimeMs: sanitizeCount(snapshot?.remainingTimeMs),
      updatedAt: sanitizeCount(snapshot?.updatedAt),
      message
    };
  }
}
