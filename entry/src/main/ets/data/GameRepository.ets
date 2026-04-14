import CommonConstants from '../common/constants/CommonConstants';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GameMode } from '../game/models/GameMode';
import { GameResult, GameResultReason } from '../game/models/GameResult';
import { GameSessionState } from '../game/models/GameSessionState';
import {
  computeAchievementProgress,
  computeAchievementUnlocked,
  copyLifecycleEntries,
  copySettings,
  copyStats,
  createAchievement,
  createDefaultAchievements,
  createDefaultStats,
  createHistoryEntry,
  createLifecycleEntry,
  createSettings,
  createStats,
  sanitizeCount,
  sanitizeHour,
  sanitizeLives,
  sanitizeMinute,
  sanitizeReminderStatus,
  sanitizeReminderToken
} from './GameRepositoryHelpers';
import { readDurableState, tryParseDurableState, writeDurableState } from './GameRepositoryStorage';
import {
  AchievementProgress,
  BackgroundPolicy,
  ClassicSessionSnapshot,
  DurableGameRepositoryState,
  DurableBackupRepositoryState,
  GameSettings,
  GameRepositoryBackupPayload,
  GameSettingsUpdate,
  LifecycleEntry,
  LifecycleSnapshot,
  PlayerStats,
  ReminderScheduleStatus,
  SessionHistoryEntry,
  LastCompletedSessionSummary,
  TimedBackgroundPolicy
} from './models/GameRepositoryTypes';

const DEFAULT_STATE_KEY = 'guess_the_num_repository_state';
const USER_LIVES_KEY = 'userLives';
const GAME_OVER_KEY = 'gameOver';
const TIMED_SESSION_PAUSED_KEY = 'timedSessionBackgroundPaused';
const TAG = 'GameRepository';
const DOMAIN = 0x0000;

export class GameRepository {
  private static readonly SCHEMA_VERSION = 1;
  private static readonly MAX_HISTORY = CommonConstants.MAX_LOGS;
  private static readonly MAX_SNAPSHOTS = CommonConstants.MAX_LOGS;

  private initialized = false;
  private storageDir: string = '';
  private storageFilePath: string = '';
  private cachedState: DurableGameRepositoryState = this.createDefaultState();

  initialize(storageDir?: string): void {
    this.configureStorage(storageDir);

    if (this.initialized) {
      hilog.info(DOMAIN, TAG, 'initialize skipped: already initialized');
      return;
    }
    hilog.info(DOMAIN, TAG, 'initialize storage path %{public}s', this.storageFilePath);

    const existingState = this.tryParseState(this.readDurableState());
    if (!existingState) {
      hilog.info(DOMAIN, TAG, 'no durable state found, creating default snapshot');
      this.writeDurableState(JSON.stringify(this.createDefaultState()));
    } else {
      hilog.info(DOMAIN, TAG, 'durable state found with %{public}d history items', existingState.history.length);
    }
    if (AppStorage.get<number>(USER_LIVES_KEY) === undefined) {
      PersistentStorage.persistProp(USER_LIVES_KEY, CommonConstants.DEFAULT_LIVES);
    }
    if (AppStorage.get<boolean>(GAME_OVER_KEY) === undefined) {
      PersistentStorage.persistProp(GAME_OVER_KEY, false);
    }
    if (AppStorage.get<boolean>(TIMED_SESSION_PAUSED_KEY) === undefined) {
      PersistentStorage.persistProp(TIMED_SESSION_PAUSED_KEY, false);
    }

    const hydrated = this.normalizeState(this.readStateInternal());
    this.cachedState = hydrated;
    hilog.info(DOMAIN, TAG, 'hydrated state history=%{public}d lives=%{public}d gameOver=%{public}s',
      hydrated.history.length, hydrated.profile.lives, JSON.stringify(hydrated.profile.gameOver));
    this.writeState(hydrated);
    this.mirrorClassicState(hydrated.profile.lives, hydrated.profile.gameOver);
    this.initialized = true;
  }

  configureStorage(storageDir?: string): void {
    if (!storageDir || storageDir.length === 0) {
      return;
    }

    const nextFilePath = `${storageDir}/${DEFAULT_STATE_KEY}.json`;
    if (this.storageFilePath === nextFilePath) {
      return;
    }

    this.storageDir = storageDir;
    this.storageFilePath = nextFilePath;
    hilog.info(DOMAIN, TAG, 'configureStorage path=%{public}s initialized=%{public}s',
      this.storageFilePath, JSON.stringify(this.initialized));

    if (this.initialized) {
      const durableState = this.tryParseState(this.readDurableState());
      if (durableState) {
        const normalizedState = this.normalizeState(durableState);
        this.cachedState = normalizedState;
        AppStorage.set<string>(DEFAULT_STATE_KEY, JSON.stringify(normalizedState));
        this.mirrorClassicState(normalizedState.profile.lives, normalizedState.profile.gameOver);
        hilog.info(DOMAIN, TAG, 'configureStorage restored durable state history=%{public}d', normalizedState.history.length);
        return;
      }
      hilog.info(DOMAIN, TAG, 'configureStorage found no durable snapshot, flushing cache history=%{public}d', this.cachedState.history.length);
      this.writeDurableState(JSON.stringify(this.cachedState));
    }
  }

  getClassicLives(): number {
    return this.getProfile().lives;
  }

  setClassicLives(lives: number): void {
    const state = this.readState();
    state.profile.lives = this.sanitizeLives(lives);
    state.profile.lastSession.lives = state.profile.lives;
    state.profile.lastSession.updatedAt = this.now();
    this.writeState(state);
    this.mirrorClassicState(state.profile.lives, state.profile.gameOver);
  }

  getGameOver(): boolean {
    return this.getProfile().gameOver;
  }

  getStats(): PlayerStats {
    return copyStats(this.getProfile().stats);
  }

  isOnboardingCompleted(): boolean {
    return this.getProfile().onboardingCompleted;
  }

  completeOnboarding(): void {
    const state = this.readState();
    state.profile.onboardingCompleted = true;
    this.writeState(state);
  }

  hasActiveClassicSession(): boolean {
    return this.getProfile().classicSessionActive;
  }

  setClassicSessionActive(active: boolean): void {
    const state = this.readState();
    state.profile.classicSessionActive = active;
    if (active) {
      state.profile.gameOver = false;
      state.profile.lastSession.gameOver = false;
      state.profile.lastSession.updatedAt = this.now();
    }
    this.writeState(state);
    this.mirrorClassicState(state.profile.lives, state.profile.gameOver);
  }

  setGameOver(gameOver: boolean): void {
    const state = this.readState();
    state.profile.gameOver = gameOver;
    if (gameOver) {
      state.profile.classicSessionActive = false;
    }
    state.profile.lastSession.gameOver = gameOver;
    state.profile.lastSession.updatedAt = this.now();
    this.writeState(state);
    this.mirrorClassicState(state.profile.lives, state.profile.gameOver);
  }

  getLastSession(): ClassicSessionSnapshot {
    return this.getProfile().lastSession;
  }

  getLastCompletedSession(): LastCompletedSessionSummary {
    return this.getProfile().lastCompletedSession;
  }

  saveClassicProgress(session: GameSessionState, message: string): void {
    const state = this.readState();
    state.profile.lives = this.sanitizeLives(session.lives);
    state.profile.gameOver = session.isGameOver;
    state.profile.classicSessionActive = !session.isGameOver;
    state.profile.lastSession = this.buildSessionSnapshot(session, this.normalizeProgressMessage(message, session.isGameOver));
    state.profile.stats.lastPlayedAt = this.now();
    this.touchAchievementProgress(state, session);
    this.writeState(state);
    this.mirrorClassicState(state.profile.lives, state.profile.gameOver);
  }

  recordCompletedSession(session: GameSessionState, result: GameResult, message: string): void {
    const state = this.readState();
    if (session.mode === GameMode.CLASSIC) {
      state.profile.lives = this.sanitizeLives(session.lives);
      state.profile.gameOver = true;
      state.profile.classicSessionActive = false;
      state.profile.lastSession = this.buildSessionSnapshot(session, message);
    }
    state.profile.lastCompletedSession = this.buildCompletedSessionSummary(session, result.reason, message);
    state.profile.stats.totalSessions += 1;
    state.profile.stats.completedSessions += 1;
    state.profile.stats.totalCorrect += session.correctCount;
    state.profile.stats.totalWrong += session.wrongCount;
    state.profile.stats.bestScore = Math.max(state.profile.stats.bestScore, result.finalScore);
    state.profile.stats.bestStreak = Math.max(state.profile.stats.bestStreak, result.bestStreak);
    state.profile.stats.longestRun = Math.max(state.profile.stats.longestRun, result.completedRounds);
    state.profile.stats.longestStreak = Math.max(state.profile.stats.longestStreak, result.bestStreak);
    if (result.mode === GameMode.TIMED) {
      state.profile.stats.bestTimedScore = Math.max(state.profile.stats.bestTimedScore, result.finalScore);
    }
    state.profile.stats.lastPlayedAt = this.now();
    state.history.push(this.buildHistoryEntry(result, session, message));
    hilog.info(DOMAIN, TAG, 'recordCompletedSession pushed history item, history=%{public}d mode=%{public}s score=%{public}d',
      state.history.length, result.mode, result.finalScore);
    if (state.history.length > GameRepository.MAX_HISTORY) {
      state.history.shift();
      hilog.info(DOMAIN, TAG, 'history trimmed to max %{public}d', GameRepository.MAX_HISTORY);
    }
    this.touchAchievementProgress(state, session, result);
    this.writeState(state);
    this.mirrorClassicState(state.profile.lives, state.profile.gameOver);
  }

  recordBackgroundPenalty(session: GameSessionState, message: string): boolean {
    const state = this.readState();
    if (!state.settings.backgroundPenaltyEnabled || !state.profile.classicSessionActive || state.profile.gameOver) {
      return false;
    }

    const penalizedLives = this.sanitizeLives(session.lives - 1);
    session.lives = penalizedLives;
    session.isGameOver = penalizedLives <= 0;

    state.profile.lives = this.sanitizeLives(session.lives);
    state.profile.gameOver = session.isGameOver;
    state.profile.classicSessionActive = !session.isGameOver;
    state.profile.lastSession = this.buildSessionSnapshot(session, message);
    state.profile.stats.backgroundPenalties += 1;
    state.profile.stats.backgroundLosses += session.isGameOver ? 1 : 0;
    state.profile.stats.lastPlayedAt = this.now();
    if (session.isGameOver) {
      const result = this.buildBackgroundLossResult(session);
      const completionSummary = 'You lost your last life in the background. Game over.';
      state.profile.lastCompletedSession = this.buildCompletedSessionSummary(session, result.reason, completionSummary);
      state.profile.stats.totalSessions += 1;
      state.profile.stats.completedSessions += 1;
      state.profile.stats.totalCorrect += session.correctCount;
      state.profile.stats.totalWrong += session.wrongCount;
      state.profile.stats.bestScore = Math.max(state.profile.stats.bestScore, result.finalScore);
      state.profile.stats.bestStreak = Math.max(state.profile.stats.bestStreak, result.bestStreak);
      state.profile.stats.longestRun = Math.max(state.profile.stats.longestRun, result.completedRounds);
      state.profile.stats.longestStreak = Math.max(state.profile.stats.longestStreak, result.bestStreak);
      state.profile.stats.lastPlayedAt = result.completedAt;
      state.history.push(this.buildHistoryEntry(result, session, completionSummary));
      if (state.history.length > GameRepository.MAX_HISTORY) {
        state.history.shift();
      }
      this.touchAchievementProgress(state, session, result);
    }
    this.writeState(state);
    this.mirrorClassicState(state.profile.lives, state.profile.gameOver);
    return true;
  }

  getHistory(): SessionHistoryEntry[] {
    return this.readState().history.slice();
  }

  getAchievements(): AchievementProgress[] {
    return this.readState().achievements.slice();
  }

  getSettings(): GameSettings {
    return copySettings(this.readState().settings);
  }

  getLifecycleBanner(): string {
    return this.getProfile().lifecycleBanner;
  }

  hasPendingLifecycleBanner(): boolean {
    return this.getProfile().pendingLifecycleBanner !== '';
  }

  consumeLifecycleBanner(): string {
    const state = this.readState();
    const banner = state.profile.pendingLifecycleBanner;
    state.profile.pendingLifecycleBanner = '';
    state.profile.lifecycleBanner = banner;
    this.writeState(state);
    return banner;
  }

  clearLifecycleBanner(): void {
    const state = this.readState();
    state.profile.pendingLifecycleBanner = '';
    state.profile.lifecycleBanner = '';
    this.writeState(state);
  }

  markTimedSessionBackgroundStarted(at: number): void {
    const state = this.readState();
    state.profile.timedSessionBackgroundStartedAt = at;
    this.writeState(state);
  }

  clearTimedSessionBackgroundStarted(): void {
    const state = this.readState();
    state.profile.timedSessionBackgroundStartedAt = 0;
    this.writeState(state);
  }

  consumeTimedSessionBackgroundElapsed(now: number): number {
    const state = this.readState();
    const startedAt = state.profile.timedSessionBackgroundStartedAt;
    if (startedAt <= 0 || now <= startedAt) {
      state.profile.timedSessionBackgroundStartedAt = 0;
      this.writeState(state);
      return 0;
    }

    state.profile.timedSessionBackgroundStartedAt = 0;
    this.writeState(state);
    return now - startedAt;
  }

  setPendingLifecycleBanner(message: string): void {
    const state = this.readState();
    state.profile.pendingLifecycleBanner = message;
    state.profile.lifecycleBanner = message;
    this.writeState(state);
  }

  setTimedSessionBackgroundPaused(paused: boolean): void {
    AppStorage.set<boolean>(TIMED_SESSION_PAUSED_KEY, paused);
  }

  isTimedSessionBackgroundPaused(): boolean {
    return AppStorage.get<boolean>(TIMED_SESSION_PAUSED_KEY) ?? false;
  }

  setLifecycleBanner(message: string): void {
    const state = this.readState();
    state.profile.lifecycleBanner = message;
    this.writeState(state);
  }

  updateSettings(updates: GameSettingsUpdate): GameSettings {
    const state = this.readState();
    state.settings = this.mergeSettings(state.settings, updates);
    this.writeState(state);
    return copySettings(state.settings);
  }

  saveLifecycleSnapshot(entries: LifecycleEntry[]): void {
    const state = this.readState();
    if (!state.settings.keepLifecycleSnapshots) {
      return;
    }

    state.lifecycleSnapshots.push(this.createLifecycleSnapshot(entries));
    if (state.lifecycleSnapshots.length > GameRepository.MAX_SNAPSHOTS) {
      state.lifecycleSnapshots.shift();
    }
    this.writeState(state);
  }

  getLifecycleSnapshots(): LifecycleSnapshot[] {
    return this.readState().lifecycleSnapshots.slice();
  }

  getLifecycleEntries(): LifecycleEntry[] {
    const snapshots = this.getLifecycleSnapshots();
    if (snapshots.length === 0) {
      return [];
    }
    return copyLifecycleEntries(snapshots[snapshots.length - 1].entries);
  }

  exportForBackup(): GameRepositoryBackupPayload {
    const state = this.readState();
    const exported: DurableBackupRepositoryState = this.createBackupState(state);

    return {
      schemaVersion: GameRepository.SCHEMA_VERSION,
      exportedAt: this.now(),
      repository: exported
    };
  }

  importFromBackup(payload: GameRepositoryBackupPayload | undefined): boolean {
    if (!payload || payload.schemaVersion !== GameRepository.SCHEMA_VERSION || !payload.repository) {
      return false;
    }

    const imported = payload.repository;
    if (!this.isValidBackupRepository(imported) || imported.schemaVersion !== GameRepository.SCHEMA_VERSION) {
      return false;
    }

    const normalized = this.normalizeState({
      schemaVersion: imported.schemaVersion,
      profile: {
        lives: imported.profile.lives,
        gameOver: imported.profile.gameOver,
        classicSessionActive: imported.profile.classicSessionActive,
        onboardingCompleted: imported.profile.onboardingCompleted,
        lifecycleBanner: '',
        pendingLifecycleBanner: '',
        timedSessionBackgroundStartedAt: 0,
        stats: imported.profile.stats,
        lastSession: imported.profile.lastSession,
        lastCompletedSession: imported.profile.lastCompletedSession
      },
      settings: {
        backgroundPenaltyEnabled: imported.settings.backgroundPenaltyEnabled,
        backgroundPolicy: imported.settings.backgroundPolicy,
        timedBackgroundPolicy: imported.settings.timedBackgroundPolicy,
        preferredMode: imported.settings.preferredMode,
        keepLifecycleSnapshots: imported.settings.keepLifecycleSnapshots,
        hapticsEnabled: imported.settings.hapticsEnabled,
        dailyReminderEnabled: imported.settings.dailyReminderEnabled,
        dailyReminderHour: imported.settings.dailyReminderHour,
        dailyReminderMinute: imported.settings.dailyReminderMinute,
        dailyReminderStatus: 'idle',
        dailyReminderToken: '',
        dailyReminderUpdatedAt: 0
      },
      history: imported.history,
      achievements: imported.achievements,
      lifecycleSnapshots: []
    });

    this.writeState(normalized);
    this.mirrorClassicState(normalized.profile.lives, normalized.profile.gameOver);
    AppStorage.set<boolean>(TIMED_SESSION_PAUSED_KEY, false);
    return true;
  }

  private isValidBackupRepository(repository: DurableBackupRepositoryState): boolean {
    return !!repository &&
      typeof repository.schemaVersion === 'number' &&
      !!repository.profile &&
      !!repository.profile.stats &&
      !!repository.profile.lastSession &&
      !!repository.profile.lastCompletedSession &&
      !!repository.settings &&
      Array.isArray(repository.history) &&
      Array.isArray(repository.achievements);
  }

  private getProfile() {
    return this.readState().profile;
  }

  private createLifecycleSnapshot(entries: LifecycleEntry[]): LifecycleSnapshot {
    return { capturedAt: this.now(), entries: copyLifecycleEntries(entries) };
  }

  private createBackupState(state: DurableGameRepositoryState): DurableBackupRepositoryState {
    return {
      schemaVersion: GameRepository.SCHEMA_VERSION,
      profile: {
        lives: state.profile.lives,
        gameOver: state.profile.gameOver,
        classicSessionActive: state.profile.classicSessionActive,
        onboardingCompleted: state.profile.onboardingCompleted,
        stats: copyStats(state.profile.stats),
        lastSession: this.normalizeSessionSnapshot(state.profile.lastSession, state.profile.lives, state.profile.gameOver),
        lastCompletedSession: this.normalizeCompletedSessionSummary(state.profile.lastCompletedSession)
      },
      settings: {
        backgroundPenaltyEnabled: state.settings.backgroundPenaltyEnabled,
        backgroundPolicy: state.settings.backgroundPolicy,
        timedBackgroundPolicy: state.settings.timedBackgroundPolicy,
        preferredMode: state.settings.preferredMode,
        keepLifecycleSnapshots: state.settings.keepLifecycleSnapshots,
        hapticsEnabled: state.settings.hapticsEnabled,
        dailyReminderEnabled: state.settings.dailyReminderEnabled,
        dailyReminderHour: state.settings.dailyReminderHour,
        dailyReminderMinute: state.settings.dailyReminderMinute
      },
      history: this.normalizeHistory(state.history),
      achievements: this.normalizeAchievements(state.achievements, state.profile.stats)
    };
  }

  private mirrorClassicState(lives: number, gameOver: boolean): void {
    AppStorage.set<number>(USER_LIVES_KEY, lives);
    AppStorage.set<boolean>(GAME_OVER_KEY, gameOver);
  }

  private readState(): DurableGameRepositoryState {
    this.ensureInitialized();
    return this.cachedState;
  }

  private readStateInternal(): DurableGameRepositoryState {
    const rawState = this.readDurableState();
    const parsed = this.tryParseState(rawState);
    const legacyLives = AppStorage.get<number>(USER_LIVES_KEY) ?? CommonConstants.DEFAULT_LIVES;
    const legacyGameOver = AppStorage.get<boolean>(GAME_OVER_KEY) ?? false;

    if (parsed && !this.shouldMigrateFromLegacy(parsed, legacyLives, legacyGameOver)) {
      hilog.info(DOMAIN, TAG, 'readStateInternal using durable parsed state history=%{public}d', parsed.history.length);
      return this.normalizeState(parsed);
    }

    hilog.info(DOMAIN, TAG, 'readStateInternal falling back to legacy migration lives=%{public}d gameOver=%{public}s',
      legacyLives, JSON.stringify(legacyGameOver));
    return this.migrateLegacyState(legacyLives, legacyGameOver);
  }

  private writeState(state: DurableGameRepositoryState): void {
    const normalizedState = this.normalizeState(state);
    this.cachedState = normalizedState;
    const serializedState = JSON.stringify(normalizedState);
    AppStorage.set<string>(DEFAULT_STATE_KEY, serializedState);
    hilog.info(DOMAIN, TAG, 'writeState history=%{public}d lives=%{public}d gameOver=%{public}s bytes=%{public}d',
      normalizedState.history.length, normalizedState.profile.lives,
      JSON.stringify(normalizedState.profile.gameOver), serializedState.length);
    this.writeDurableState(serializedState);
  }

  private ensureInitialized(): void {
    if (!this.initialized) {
      this.initialize();
    }
  }

  private migrateLegacyState(legacyLives: number, legacyGameOver: boolean): DurableGameRepositoryState {
    const sanitizedLives = this.sanitizeLives(legacyLives);
    const state = this.createDefaultState();
    state.profile.lives = sanitizedLives;
    state.profile.gameOver = legacyGameOver;
    state.profile.lastSession = this.buildLegacySessionSnapshot(sanitizedLives, legacyGameOver);
    this.writeState(state);
    this.mirrorClassicState(sanitizedLives, legacyGameOver);
    return state;
  }

  private shouldMigrateFromLegacy(state: DurableGameRepositoryState, legacyLives: number, legacyGameOver: boolean): boolean {
    const rawStateLooksDefault = this.isDefaultRepositoryShape(state);
    const legacyDiffersFromDefault = this.sanitizeLives(legacyLives) !== CommonConstants.DEFAULT_LIVES || legacyGameOver !== false;
    return rawStateLooksDefault && legacyDiffersFromDefault;
  }

  private isDefaultRepositoryShape(state: DurableGameRepositoryState): boolean {
    return state?.schemaVersion === GameRepository.SCHEMA_VERSION &&
      this.sanitizeLives(state?.profile?.lives) === CommonConstants.DEFAULT_LIVES &&
      (state?.profile?.gameOver ?? false) === false &&
      (state?.profile?.classicSessionActive ?? false) === false &&
      this.sanitizeCount(state?.profile?.stats?.totalSessions) === 0 &&
      this.sanitizeCount(state?.profile?.stats?.completedSessions) === 0 &&
      this.sanitizeCount(state?.profile?.stats?.totalCorrect) === 0 &&
      this.sanitizeCount(state?.profile?.stats?.totalWrong) === 0 &&
       this.sanitizeCount(state?.profile?.stats?.bestScore) === 0 &&
       this.sanitizeCount(state?.profile?.stats?.bestStreak) === 0 &&
       this.sanitizeCount(state?.profile?.stats?.longestRun) === 0 &&
       this.sanitizeCount(state?.profile?.stats?.longestStreak) === 0 &&
       this.sanitizeCount(state?.profile?.stats?.bestTimedScore) === 0 &&
       this.sanitizeCount(state?.profile?.stats?.backgroundPenalties) === 0 &&
       this.sanitizeCount(state?.profile?.stats?.backgroundLosses) === 0 &&
       this.sanitizeCount(state?.profile?.stats?.lastPlayedAt) === 0 &&
      this.sanitizeLives(state?.profile?.lastSession?.lives) === CommonConstants.DEFAULT_LIVES &&
      (state?.profile?.lastSession?.gameOver ?? false) === false &&
      this.sanitizeCount(state?.history?.length) === 0 &&
      this.sanitizeCount(state?.lifecycleSnapshots?.length) === 0 &&
      this.sanitizeCount(state?.achievements?.length) >= 0;
  }

  private normalizeState(state: DurableGameRepositoryState): DurableGameRepositoryState {
    const normalized = this.createDefaultState();
    normalized.schemaVersion = GameRepository.SCHEMA_VERSION;
    normalized.profile.lives = this.sanitizeLives(state?.profile?.lives ?? CommonConstants.DEFAULT_LIVES);
    normalized.profile.gameOver = state?.profile?.gameOver ?? false;
    normalized.profile.classicSessionActive = state?.profile?.classicSessionActive ?? false;
    normalized.profile.onboardingCompleted = state?.profile?.onboardingCompleted ?? false;
    normalized.profile.lifecycleBanner = state?.profile?.lifecycleBanner ?? '';
    normalized.profile.pendingLifecycleBanner = state?.profile?.pendingLifecycleBanner ?? '';
    normalized.profile.timedSessionBackgroundStartedAt = this.sanitizeCount(state?.profile?.timedSessionBackgroundStartedAt);
    normalized.profile.stats = createStats(
      this.sanitizeCount(state?.profile?.stats?.totalSessions),
      this.sanitizeCount(state?.profile?.stats?.completedSessions),
      this.sanitizeCount(state?.profile?.stats?.totalCorrect),
      this.sanitizeCount(state?.profile?.stats?.totalWrong),
      this.sanitizeCount(state?.profile?.stats?.bestScore),
      this.sanitizeCount(state?.profile?.stats?.bestStreak),
      this.sanitizeCount(state?.profile?.stats?.longestRun),
      this.sanitizeCount(state?.profile?.stats?.longestStreak ?? state?.profile?.stats?.bestStreak),
      this.sanitizeCount(state?.profile?.stats?.bestTimedScore),
      this.sanitizeCount(state?.profile?.stats?.backgroundPenalties),
      this.sanitizeCount(state?.profile?.stats?.backgroundLosses),
      this.sanitizeCount(state?.profile?.stats?.lastPlayedAt)
    );
    normalized.profile.lastSession = this.normalizeSessionSnapshot(state?.profile?.lastSession, normalized.profile.lives, normalized.profile.gameOver);
    normalized.profile.lastCompletedSession = this.normalizeCompletedSessionSummary(state?.profile?.lastCompletedSession);
    normalized.settings = this.normalizeSettings(state?.settings);
    normalized.history = this.normalizeHistory(state?.history);
    normalized.achievements = this.normalizeAchievements(state?.achievements, normalized.profile.stats);
    normalized.lifecycleSnapshots = this.normalizeSnapshots(state?.lifecycleSnapshots);
    return normalized;
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
      dailyReminderHour: this.sanitizeHour(settings?.dailyReminderHour ?? defaults.dailyReminderHour),
      dailyReminderMinute: this.sanitizeMinute(settings?.dailyReminderMinute ?? defaults.dailyReminderMinute),
      dailyReminderStatus: this.sanitizeReminderStatus(settings?.dailyReminderStatus ?? defaults.dailyReminderStatus),
      dailyReminderToken: this.sanitizeReminderToken(settings?.dailyReminderToken ?? defaults.dailyReminderToken),
      dailyReminderUpdatedAt: this.sanitizeCount(settings?.dailyReminderUpdatedAt ?? defaults.dailyReminderUpdatedAt)
    };
  }

  private mergeSettings(current: GameSettings, updates: GameSettingsUpdate): GameSettings {
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

  private normalizeHistory(history?: SessionHistoryEntry[]): SessionHistoryEntry[] {
    const result: SessionHistoryEntry[] = [];
    if (!history) {
      return result;
    }

    for (const item of history) {
      result.push(createHistoryEntry(
        item?.sessionId ?? this.makeSessionId(), item?.mode ?? GameMode.CLASSIC,
        item?.reason ?? GameResultReason.OUT_OF_LIVES, item?.summary ?? 'Saved session',
        this.sanitizeCount(item?.score), this.sanitizeLives(item?.livesRemaining ?? CommonConstants.DEFAULT_LIVES),
        this.sanitizeCount(item?.correctCount), this.sanitizeCount(item?.wrongCount),
        this.sanitizeCount(item?.bestStreak), this.sanitizeCount(item?.completedRounds),
        this.sanitizeCount(item?.completedAt)
      ));
    }

    return result;
  }

  private normalizeAchievements(achievements: AchievementProgress[] | undefined, stats: PlayerStats): AchievementProgress[] {
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
        unlocked && achievement.unlockedAt === 0 ? this.now() : achievement.unlockedAt
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
      result.push({ capturedAt: this.sanitizeCount(snapshot?.capturedAt), entries: this.normalizeLifecycleEntries(snapshot?.entries, snapshot?.messages) });
    }
    return result;
  }

  private normalizeLifecycleEntries(entries?: LifecycleEntry[], legacyMessages?: string[]): LifecycleEntry[] {
    if (entries && entries.length > 0) {
      return copyLifecycleEntries(entries);
    }

    if (legacyMessages && legacyMessages.length > 0) {
      const legacyEntries: LifecycleEntry[] = [];
      for (const message of legacyMessages) {
        legacyEntries.push(createLifecycleEntry(this.now(), 'Lifecycle', message));
      }
      return legacyEntries;
    }

    return [];
  }

  private normalizeSessionSnapshot(snapshot: ClassicSessionSnapshot | undefined, lives: number, gameOver: boolean): ClassicSessionSnapshot {
    const message = this.normalizeProgressMessage(snapshot?.message ?? '', gameOver);
    return {
      mode: snapshot?.mode ?? GameMode.CLASSIC,
      lives: this.sanitizeLives(snapshot?.lives ?? lives),
      gameOver: snapshot?.gameOver ?? gameOver,
      score: this.sanitizeCount(snapshot?.score),
      streak: this.sanitizeCount(snapshot?.streak),
      bestStreak: this.sanitizeCount(snapshot?.bestStreak),
      correctCount: this.sanitizeCount(snapshot?.correctCount),
      wrongCount: this.sanitizeCount(snapshot?.wrongCount),
      completedRounds: this.sanitizeCount(snapshot?.completedRounds),
      sequenceIndex: this.sanitizeCount(snapshot?.sequenceIndex),
      turnIndex: this.sanitizeCount(snapshot?.turnIndex),
      roundDelayMs: this.sanitizeCount(snapshot?.roundDelayMs ?? CommonConstants.DEFAULT_ROUND_DELAY_MS),
      timeLimitMs: this.sanitizeCount(snapshot?.timeLimitMs),
      remainingTimeMs: this.sanitizeCount(snapshot?.remainingTimeMs),
      updatedAt: this.sanitizeCount(snapshot?.updatedAt),
      message
    };
  }

  private normalizeProgressMessage(message: string, gameOver: boolean): string {
    if (gameOver) {
      return message;
    }

    if (message === 'Correct!' || message.startsWith('Wrong! It was ')) {
      return '';
    }

    return message;
  }

  private buildSessionSnapshot(session: GameSessionState, message: string): ClassicSessionSnapshot {
    return {
      mode: session.mode,
      lives: this.sanitizeLives(session.lives),
      gameOver: session.isGameOver,
      score: this.sanitizeCount(session.score),
      streak: this.sanitizeCount(session.streak),
      bestStreak: this.sanitizeCount(session.bestStreak),
      correctCount: this.sanitizeCount(session.correctCount),
      wrongCount: this.sanitizeCount(session.wrongCount),
      completedRounds: this.sanitizeCount(session.completedRounds),
      sequenceIndex: this.sanitizeCount(session.sequenceIndex),
      turnIndex: this.sanitizeCount(session.turnIndex),
      roundDelayMs: this.sanitizeCount(session.roundDelayMs),
      timeLimitMs: this.sanitizeCount(session.timeLimitMs),
      remainingTimeMs: this.sanitizeCount(session.remainingTimeMs),
      updatedAt: this.now(),
      message
    };
  }

  private buildLegacySessionSnapshot(lives: number, gameOver: boolean): ClassicSessionSnapshot {
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
      updatedAt: this.now(),
      message: gameOver ? 'You ran out of lives! Game over.' : 'Restored classic progress.'
    };
  }

  private buildEmptySessionSnapshot(lives: number, gameOver: boolean): ClassicSessionSnapshot {
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

  private buildEmptyCompletedSessionSummary(): LastCompletedSessionSummary {
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

  private buildCompletedSessionSummary(session: GameSessionState, reason: GameResultReason, message: string): LastCompletedSessionSummary {
    return {
      sessionId: this.makeSessionId(),
      mode: session.mode,
      reason,
      summary: message,
      score: this.sanitizeCount(session.score),
      livesRemaining: this.sanitizeLives(session.lives),
      correctCount: this.sanitizeCount(session.correctCount),
      wrongCount: this.sanitizeCount(session.wrongCount),
      bestStreak: this.sanitizeCount(session.bestStreak),
      completedRounds: this.sanitizeCount(session.completedRounds),
      completedAt: this.now()
    };
  }

  private buildBackgroundLossResult(session: GameSessionState): GameResult {
    return {
      mode: session.mode,
      reason: GameResultReason.OUT_OF_LIVES,
      finalScore: this.sanitizeCount(session.score),
      livesRemaining: this.sanitizeLives(session.lives),
      correctCount: this.sanitizeCount(session.correctCount),
      wrongCount: this.sanitizeCount(session.wrongCount),
      bestStreak: this.sanitizeCount(session.bestStreak),
      completedRounds: this.sanitizeCount(session.completedRounds),
      completedAt: this.now()
    };
  }

  private normalizeCompletedSessionSummary(summary?: LastCompletedSessionSummary): LastCompletedSessionSummary {
    if (!summary) {
      return this.buildEmptyCompletedSessionSummary();
    }

    return {
      sessionId: summary.sessionId ?? this.makeSessionId(),
      mode: summary.mode ?? GameMode.CLASSIC,
      reason: summary.reason ?? GameResultReason.OUT_OF_LIVES,
      summary: summary.summary ?? '',
      score: this.sanitizeCount(summary.score),
      livesRemaining: this.sanitizeLives(summary.livesRemaining),
      correctCount: this.sanitizeCount(summary.correctCount),
      wrongCount: this.sanitizeCount(summary.wrongCount),
      bestStreak: this.sanitizeCount(summary.bestStreak),
      completedRounds: this.sanitizeCount(summary.completedRounds),
      completedAt: this.sanitizeCount(summary.completedAt)
    };
  }

  private buildHistoryEntry(result: GameResult, session: GameSessionState, message: string): SessionHistoryEntry {
    return {
      sessionId: this.makeSessionId(),
      mode: result.mode,
      reason: result.reason,
      summary: message,
      score: this.sanitizeCount(result.finalScore),
      livesRemaining: this.sanitizeLives(result.livesRemaining),
      correctCount: this.sanitizeCount(result.correctCount),
      wrongCount: this.sanitizeCount(result.wrongCount),
      bestStreak: this.sanitizeCount(result.bestStreak),
      completedRounds: this.sanitizeCount(session.completedRounds),
      completedAt: this.sanitizeCount(result.completedAt)
    };
  }

  private touchAchievementProgress(state: DurableGameRepositoryState, session: GameSessionState, result?: GameResult): void {
    state.achievements = this.applyAchievementProgress(state.achievements, state.profile.stats);
    if (result) {
      state.profile.stats.bestScore = Math.max(state.profile.stats.bestScore, result.finalScore);
      state.profile.stats.bestStreak = Math.max(state.profile.stats.bestStreak, result.bestStreak);
    } else {
      state.profile.stats.bestStreak = Math.max(state.profile.stats.bestStreak, session.bestStreak);
    }
  }

  private createDefaultState(): DurableGameRepositoryState {
    return {
      schemaVersion: GameRepository.SCHEMA_VERSION,
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

  private tryParseState(rawState: string | undefined): DurableGameRepositoryState | undefined {
    return tryParseDurableState<DurableGameRepositoryState>(rawState, DOMAIN, TAG);
  }

  private readDurableState(): string {
    return readDurableState(this.storageFilePath, DEFAULT_STATE_KEY, DOMAIN, TAG);
  }

  private writeDurableState(serializedState: string): void {
    writeDurableState(this.storageDir, this.storageFilePath, serializedState, DOMAIN, TAG);
  }

  private sanitizeLives(value: number | undefined): number {
    return sanitizeLives(value);
  }

  private sanitizeCount(value: number | undefined): number {
    return sanitizeCount(value);
  }

  private sanitizeHour(value: number): number {
    return sanitizeHour(value);
  }

  private sanitizeMinute(value: number): number {
    return sanitizeMinute(value);
  }

  private sanitizeReminderStatus(value: string): ReminderScheduleStatus {
    return sanitizeReminderStatus(value);
  }

  private sanitizeReminderToken(value: string | undefined): string {
    return sanitizeReminderToken(value);
  }

  private makeSessionId(): string {
    return `session-${this.now()}-${Math.floor(Math.random() * 10000)}`;
  }

  private now(): number {
    return new Date().getTime();
  }
}

export const gameRepository = new GameRepository();
