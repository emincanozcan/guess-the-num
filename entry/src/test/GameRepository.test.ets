import { describe, it, expect } from '@ohos/hypium';
import CommonConstants from '../main/ets/common/constants/CommonConstants';
import { GameRepository } from '../main/ets/data/GameRepository';
import { GameSessionState } from '../main/ets/game/models/GameSessionState';
import { GameMode } from '../main/ets/game/models/GameMode';
import {
  AchievementProgress,
  BackupProfile,
  BackupSettings,
  ClassicSessionSnapshot,
  DurableGameRepositoryState,
  GameRepositoryBackupPayload,
  LastCompletedSessionSummary,
  LifecycleEntry,
  LifecycleSnapshot,
  PlayerStats,
  SessionHistoryEntry
} from '../main/ets/data/models/GameRepositoryTypes';

const DEFAULT_STATE_KEY = 'guess_the_num_repository_state';
const USER_LIVES_KEY = 'userLives';
const GAME_OVER_KEY = 'gameOver';

interface InvalidRepositoryPayloadShape {
  schemaVersion: number;
}

interface InvalidBackupPayloadShape {
  schemaVersion: number;
  exportedAt: number;
  repository: InvalidRepositoryPayloadShape;
}

interface MissingProfileRepositoryShape {
  schemaVersion: number;
  settings: BackupSettings;
  history: SessionHistoryEntry[];
  achievements: AchievementProgress[];
}

interface MissingProfileBackupPayloadShape {
  schemaVersion: number;
  exportedAt: number;
  repository: MissingProfileRepositoryShape;
}

interface MissingSettingsRepositoryShape {
  schemaVersion: number;
  profile: BackupProfile;
  history: SessionHistoryEntry[];
  achievements: AchievementProgress[];
}

interface MissingSettingsBackupPayloadShape {
  schemaVersion: number;
  exportedAt: number;
  repository: MissingSettingsRepositoryShape;
}

export default function gameRepositoryTest() {
  describe('gameRepositoryTest', () => {
    it('persists settings updates inside the active repository state', 0, () => {
      bootstrapRepository();

      const firstRepo = new GameRepository();
      firstRepo.initialize();
      const savedSettings = firstRepo.updateSettings({
        backgroundPenaltyEnabled: false,
        timedBackgroundPolicy: 'log-only',
        preferredMode: GameMode.TIMED,
        keepLifecycleSnapshots: false,
        hapticsEnabled: false,
        dailyReminderEnabled: true,
        dailyReminderHour: 9,
        dailyReminderMinute: 30,
        dailyReminderStatus: 'scheduled',
        dailyReminderToken: 'reminder-42'
      });

      expect(savedSettings.backgroundPenaltyEnabled).assertEqual(false);
      expect(savedSettings.timedBackgroundPolicy).assertEqual('log-only');
      expect(savedSettings.preferredMode).assertEqual(GameMode.TIMED);
      expect(savedSettings.keepLifecycleSnapshots).assertEqual(false);
      expect(savedSettings.hapticsEnabled).assertEqual(false);
      expect(savedSettings.dailyReminderEnabled).assertEqual(true);
      expect(savedSettings.dailyReminderHour).assertEqual(9);
      expect(savedSettings.dailyReminderMinute).assertEqual(30);
      expect(savedSettings.dailyReminderStatus).assertEqual('scheduled');
      expect(savedSettings.dailyReminderToken).assertEqual('reminder-42');

      const restoredSettings = firstRepo.getSettings();

      expect(restoredSettings.backgroundPenaltyEnabled).assertEqual(false);
      expect(restoredSettings.timedBackgroundPolicy).assertEqual('log-only');
      expect(restoredSettings.preferredMode).assertEqual(GameMode.TIMED);
      expect(restoredSettings.keepLifecycleSnapshots).assertEqual(false);
      expect(restoredSettings.hapticsEnabled).assertEqual(false);
      expect(restoredSettings.dailyReminderEnabled).assertEqual(true);
      expect(restoredSettings.dailyReminderHour).assertEqual(9);
      expect(restoredSettings.dailyReminderMinute).assertEqual(30);
      expect(restoredSettings.dailyReminderStatus).assertEqual('scheduled');
      expect(restoredSettings.dailyReminderToken).assertEqual('reminder-42');
    });

    it('defaults safely when the stored repository state is corrupt', 0, () => {
      bootstrapRepository();
      AppStorage.set<string>(DEFAULT_STATE_KEY, '{broken-json');
      AppStorage.set<number>(USER_LIVES_KEY, CommonConstants.DEFAULT_LIVES);
      AppStorage.set<boolean>(GAME_OVER_KEY, false);

      const repo = new GameRepository();
      repo.initialize();

      const settings = repo.getSettings();
      expect(settings.backgroundPenaltyEnabled).assertEqual(true);
      expect(settings.preferredMode).assertEqual(GameMode.CLASSIC);
      expect(settings.keepLifecycleSnapshots).assertEqual(true);
      expect(settings.hapticsEnabled).assertEqual(true);
      expect(settings.dailyReminderEnabled).assertEqual(false);
      expect(settings.dailyReminderHour).assertEqual(20);
      expect(settings.dailyReminderMinute).assertEqual(0);
      expect(settings.dailyReminderStatus).assertEqual('idle');
      expect(settings.dailyReminderToken).assertEqual('');
      expect(repo.getClassicLives()).assertEqual(CommonConstants.DEFAULT_LIVES);
      expect(repo.getGameOver()).assertEqual(false);
    });

    it('honors background penalty settings when applying hidden penalties', 0, () => {
      bootstrapRepository();

      const repo = new GameRepository();
      repo.initialize();
      repo.updateSettings({ backgroundPenaltyEnabled: false });
      repo.setClassicSessionActive(true);

      const disabledSession = createBackgroundPenaltySession(2);
      const disabledApplied = repo.recordBackgroundPenalty(disabledSession, '🔒 Application is in background');
      expect(disabledApplied).assertEqual(false);
      expect(disabledSession.lives).assertEqual(2);
      expect(repo.getClassicLives()).assertEqual(CommonConstants.DEFAULT_LIVES);

      repo.updateSettings({ backgroundPenaltyEnabled: true });
      const enabledSession = createBackgroundPenaltySession(2);
      const enabledApplied = repo.recordBackgroundPenalty(enabledSession, '🔒 Application is in background');
      expect(enabledApplied).assertEqual(true);
      expect(enabledSession.lives).assertEqual(1);
      expect(enabledSession.isGameOver).assertEqual(false);
      expect(repo.getClassicLives()).assertEqual(1);
      expect(repo.getLastSession().message).assertEqual('🔒 Application is in background');
    });

    it('persists timed-session background pause state', 0, () => {
      bootstrapRepository();

      const repo = new GameRepository();
      repo.initialize();

      repo.setTimedSessionBackgroundPaused(true);
      expect(repo.isTimedSessionBackgroundPaused()).assertEqual(true);

      const coldRepo = new GameRepository();
      coldRepo.initialize();
      expect(coldRepo.isTimedSessionBackgroundPaused()).assertEqual(true);

      repo.setTimedSessionBackgroundPaused(false);
      expect(repo.isTimedSessionBackgroundPaused()).assertEqual(false);
    });

    it('persists background-loss completions once when lives reach zero', 0, () => {
      bootstrapRepository();

      const repo = new GameRepository();
      repo.initialize();
      repo.setClassicSessionActive(true);

      const losingSession = createBackgroundPenaltySession(1);
      const applied = repo.recordBackgroundPenalty(losingSession, 'You ran out of lives! Game over.');

      expect(applied).assertEqual(true);
      expect(losingSession.lives).assertEqual(0);
      expect(losingSession.isGameOver).assertEqual(true);
      expect(repo.getLastSession().message).assertEqual('You ran out of lives! Game over.');

      const lastCompletedSession = repo.getLastCompletedSession();
      expect(lastCompletedSession.reason).assertEqual('out_of_lives');
      expect(lastCompletedSession.livesRemaining).assertEqual(0);
      expect(lastCompletedSession.summary).assertEqual('You lost your last life in the background. Game over.');

      const historyEntry = repo.getHistory()[0];
      expect(historyEntry.summary).assertEqual('You lost your last life in the background. Game over.');

      expect(repo.getHistory().length).assertEqual(1);
      expect(repo.getStats().completedSessions).assertEqual(1);

      const reapplied = repo.recordBackgroundPenalty(losingSession, 'You ran out of lives! Game over.');
      expect(reapplied).assertEqual(false);
      expect(repo.getHistory().length).assertEqual(1);
      expect(repo.getStats().completedSessions).assertEqual(1);
    });

    it('tracks timed background elapsed and pending resume banners', 0, () => {
      bootstrapRepository();

      const repo = new GameRepository();
      repo.initialize();

      repo.setPendingLifecycleBanner('Returned to the foreground. Timed countdown was adjusted for time spent away.');
      expect(repo.consumeLifecycleBanner()).assertEqual('Returned to the foreground. Timed countdown was adjusted for time spent away.');
      expect(repo.consumeLifecycleBanner()).assertEqual('');

      repo.markTimedSessionBackgroundStarted(1000);
      expect(repo.consumeTimedSessionBackgroundElapsed(2500)).assertEqual(1500);
      expect(repo.consumeTimedSessionBackgroundElapsed(4000)).assertEqual(0);

      repo.markTimedSessionBackgroundStarted(5000);
      repo.clearTimedSessionBackgroundStarted();
      expect(repo.consumeTimedSessionBackgroundElapsed(7000)).assertEqual(0);
    });

    it('does not penalize backgrounding when no classic session is active', 0, () => {
      bootstrapRepository();

      const repo = new GameRepository();
      repo.initialize();

      const idleSession = createBackgroundPenaltySession(CommonConstants.DEFAULT_LIVES);
      const applied = repo.recordBackgroundPenalty(idleSession, '🔒 Application is in background');

      expect(applied).assertEqual(false);
      expect(idleSession.lives).assertEqual(CommonConstants.DEFAULT_LIVES);
      expect(repo.getClassicLives()).assertEqual(CommonConstants.DEFAULT_LIVES);
    });

    it('does not re-penalize a finished game-over session', 0, () => {
      bootstrapRepository();

      const repo = new GameRepository();
      repo.initialize();
      repo.setGameOver(true);
      repo.setClassicSessionActive(false);

      const finishedSession = createBackgroundPenaltySession(1);
      const applied = repo.recordBackgroundPenalty(finishedSession, '🔒 Application is in background');

      expect(applied).assertEqual(false);
      expect(finishedSession.lives).assertEqual(1);
      expect(finishedSession.isGameOver).assertEqual(false);
      expect(repo.getClassicLives()).assertEqual(CommonConstants.DEFAULT_LIVES);
    });

    it('does not persist transient result messages for active classic progress', 0, () => {
      bootstrapRepository();

      const repo = new GameRepository();
      repo.initialize();

      const session = createActiveSession();
      repo.saveClassicProgress(session, 'Correct!');

      const savedSession = repo.getLastSession();
      expect(savedSession.lives).assertEqual(2);
      expect(savedSession.gameOver).assertEqual(false);
      expect(savedSession.message).assertEqual('');
    });

    it('clears stale turn result messages when restoring classic state', 0, () => {
      bootstrapRepository();
      AppStorage.set<string>(DEFAULT_STATE_KEY, JSON.stringify(createStateWithStaleResultMessage()));

      const repo = new GameRepository();
      repo.initialize();

      const lastSession = repo.getLastSession();
      expect(lastSession.gameOver).assertEqual(false);
      expect(lastSession.message).assertEqual('');
    });

    it('skips lifecycle snapshot persistence when disabled', 0, () => {
      bootstrapRepository();

      const repo = new GameRepository();
      repo.initialize();
      repo.updateSettings({ keepLifecycleSnapshots: false });

      const firstEntries: LifecycleEntry[] = [{ capturedAt: 111, stage: 'background', message: 'first' }];
      repo.saveLifecycleSnapshot(firstEntries);
      expect(repo.getLifecycleSnapshots().length).assertEqual(0);

      repo.updateSettings({ keepLifecycleSnapshots: true });
      const entries: LifecycleEntry[] = [{ capturedAt: 123, stage: 'foreground', message: 'second' }];
      repo.saveLifecycleSnapshot(entries);
      const snapshots = repo.getLifecycleSnapshots();
      expect(snapshots.length).assertEqual(1);
      expect(snapshots[0].entries[0].message).assertEqual('second');
      expect(repo.getLifecycleEntries()[0].message).assertEqual('second');
    });

    it('exports and imports backup payload with normalization and transient resets', 0, () => {
      bootstrapRepository();

      const repo = new GameRepository();
      repo.initialize();
      repo.saveClassicProgress(createActiveSession(), 'Correct!');
      repo.setPendingLifecycleBanner('Resume message');
      repo.markTimedSessionBackgroundStarted(1200);
      repo.setTimedSessionBackgroundPaused(true);
      repo.updateSettings({
        dailyReminderEnabled: true,
        dailyReminderHour: 8,
        dailyReminderMinute: 25,
        dailyReminderStatus: 'scheduled',
        dailyReminderToken: 'runtime-token',
        dailyReminderUpdatedAt: 999
      });

      const payload = repo.exportForBackup();
      expect(payload.schemaVersion).assertEqual(1);
      expect(payload.repository.settings.dailyReminderEnabled).assertEqual(true);
      expect(payload.repository.settings.dailyReminderHour).assertEqual(8);
      expect(payload.repository.settings.dailyReminderMinute).assertEqual(25);
      const rawRepository = payload.repository as Object as DurableBackupRepositoryStateProbe;
      expect(rawRepository.lifecycleSnapshots).assertEqual(undefined);
      const rawProfile = payload.repository.profile as Object as BackupProfileProbe;
      expect(rawProfile.pendingLifecycleBanner).assertEqual(undefined);
      expect(rawProfile.timedSessionBackgroundStartedAt).assertEqual(undefined);

      const restored = new GameRepository();
      restored.initialize();
      const imported = restored.importFromBackup(payload);

      expect(imported).assertEqual(true);
      expect(restored.getLastSession().message).assertEqual('');
      expect(restored.hasPendingLifecycleBanner()).assertEqual(false);
      expect(restored.consumeTimedSessionBackgroundElapsed(5000)).assertEqual(0);
      expect(restored.isTimedSessionBackgroundPaused()).assertEqual(false);
      const restoredSettings = restored.getSettings();
      expect(restoredSettings.dailyReminderStatus).assertEqual('idle');
      expect(restoredSettings.dailyReminderToken).assertEqual('');
      expect(restoredSettings.dailyReminderUpdatedAt).assertEqual(0);
      expect(restoredSettings.dailyReminderEnabled).assertEqual(true);
      expect(restoredSettings.dailyReminderHour).assertEqual(8);
      expect(restoredSettings.dailyReminderMinute).assertEqual(25);
    });

    it('skips invalid backup payload imports without mutating state', 0, () => {
      bootstrapRepository();

      const repo = new GameRepository();
      repo.initialize();
      repo.setClassicLives(1);

      const invalidPayload: InvalidBackupPayloadShape = {
        schemaVersion: 999,
        exportedAt: 123,
        repository: { schemaVersion: 999 }
      };

      const imported = repo.importFromBackup(JSON.parse(JSON.stringify(invalidPayload)) as GameRepositoryBackupPayload);
      expect(imported).assertEqual(false);
      expect(repo.getClassicLives()).assertEqual(1);
    });

    it('rejects partial backup payloads without throwing and keeps state intact', 0, () => {
      bootstrapRepository();

      const repo = new GameRepository();
      repo.initialize();
      repo.setClassicLives(2);

      const missingProfilePayload: MissingProfileBackupPayloadShape = {
        schemaVersion: 1,
        exportedAt: 1,
        repository: {
          schemaVersion: 1,
          settings: {
            backgroundPenaltyEnabled: true,
            backgroundPolicy: 'penalize',
            timedBackgroundPolicy: 'pause',
            preferredMode: GameMode.CLASSIC,
            keepLifecycleSnapshots: true,
            hapticsEnabled: true,
            dailyReminderEnabled: false,
            dailyReminderHour: 9,
            dailyReminderMinute: 0
          },
          history: [],
          achievements: []
        }
      };

      const missingSettingsPayload: MissingSettingsBackupPayloadShape = {
        schemaVersion: 1,
        exportedAt: 1,
        repository: {
          schemaVersion: 1,
          profile: {
            lives: 1,
            gameOver: false,
            classicSessionActive: false,
            onboardingCompleted: false,
            stats: repo.getStats(),
            lastSession: repo.getLastSession(),
            lastCompletedSession: repo.getLastCompletedSession()
          },
          history: [],
          achievements: []
        }
      };

      expect(repo.importFromBackup(JSON.parse(JSON.stringify(missingProfilePayload)) as GameRepositoryBackupPayload)).assertEqual(false);
      expect(repo.importFromBackup(JSON.parse(JSON.stringify(missingSettingsPayload)) as GameRepositoryBackupPayload)).assertEqual(false);
      expect(repo.getClassicLives()).assertEqual(2);
    });
  });
}

function bootstrapRepository(): void {
  AppStorage.set<string>(DEFAULT_STATE_KEY, JSON.stringify(createDefaultDurableState()));
  AppStorage.set<number>(USER_LIVES_KEY, CommonConstants.DEFAULT_LIVES);
  AppStorage.set<boolean>(GAME_OVER_KEY, false);

  const repository = new GameRepository();
  repository.initialize();
}

function createBackgroundPenaltySession(lives: number): GameSessionState {
  return {
    mode: GameMode.CLASSIC,
    lives,
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
    isGameOver: false
  };
}

function createActiveSession(): GameSessionState {
  return {
    mode: GameMode.CLASSIC,
    lives: 2,
    score: 1,
    streak: 1,
    bestStreak: 1,
    correctCount: 1,
    wrongCount: 0,
    completedRounds: 1,
    sequenceIndex: 1,
    turnIndex: 1,
    roundDelayMs: CommonConstants.DEFAULT_ROUND_DELAY_MS,
    timeLimitMs: 0,
    remainingTimeMs: 0,
    isGameOver: false
  };
}

interface BackupProfileProbe {
  pendingLifecycleBanner?: string;
  timedSessionBackgroundStartedAt?: number;
}

interface DurableBackupRepositoryStateProbe {
  lifecycleSnapshots?: LifecycleSnapshot[];
}

function createPlayerStats(): PlayerStats {
  return {
    totalSessions: 0,
    completedSessions: 0,
    totalCorrect: 0,
    totalWrong: 0,
    bestScore: 0,
    bestStreak: 0,
    longestRun: 0,
    longestStreak: 0,
    bestTimedScore: 0,
    backgroundPenalties: 0,
    backgroundLosses: 0,
    lastPlayedAt: 0
  };
}

function createLastCompletedSessionSummary(): LastCompletedSessionSummary {
  return {
    sessionId: '',
    mode: GameMode.CLASSIC,
    reason: '',
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

function createClassicSnapshot(lives: number, score: number, streak: number, completedRounds: number, sequenceIndex: number,
  turnIndex: number, updatedAt: number, message: string): ClassicSessionSnapshot {
  return {
    mode: GameMode.CLASSIC,
    lives: lives,
    gameOver: false,
    score: score,
    streak: streak,
    bestStreak: streak,
    correctCount: score,
    wrongCount: 0,
    completedRounds: completedRounds,
    sequenceIndex: sequenceIndex,
    turnIndex: turnIndex,
    roundDelayMs: CommonConstants.DEFAULT_ROUND_DELAY_MS,
    timeLimitMs: 0,
    remainingTimeMs: 0,
    updatedAt: updatedAt,
    message: message
  };
}

function createBackupSettings(): BackupSettings {
  return {
    backgroundPenaltyEnabled: true,
    backgroundPolicy: 'penalize',
    timedBackgroundPolicy: 'pause',
    preferredMode: GameMode.CLASSIC,
    keepLifecycleSnapshots: true,
    hapticsEnabled: true,
    dailyReminderEnabled: false,
    dailyReminderHour: 9,
    dailyReminderMinute: 0
  };
}

function createBackupProfile(repo: GameRepository, lives: number): BackupProfile {
  return {
    lives: lives,
    gameOver: false,
    classicSessionActive: false,
    onboardingCompleted: false,
    stats: repo.getStats(),
    lastSession: repo.getLastSession(),
    lastCompletedSession: repo.getLastCompletedSession()
  };
}

function createStateWithStaleResultMessage(): DurableGameRepositoryState {
  return {
    schemaVersion: 1,
    profile: {
      lives: 2,
      gameOver: false,
      classicSessionActive: false,
      onboardingCompleted: false,
      lifecycleBanner: '',
      pendingLifecycleBanner: '',
      timedSessionBackgroundStartedAt: 0,
      stats: createPlayerStats(),
      lastSession: createClassicSnapshot(2, 1, 1, 1, 2, 2, 123, 'Wrong! It was 2'),
      lastCompletedSession: createLastCompletedSessionSummary()
    },
    settings: {
      backgroundPenaltyEnabled: true,
      backgroundPolicy: 'penalize',
      timedBackgroundPolicy: 'pause',
      preferredMode: GameMode.CLASSIC,
      keepLifecycleSnapshots: true,
      hapticsEnabled: true,
      dailyReminderEnabled: false,
      dailyReminderHour: 20,
      dailyReminderMinute: 0,
      dailyReminderStatus: 'idle',
      dailyReminderToken: '',
      dailyReminderUpdatedAt: 0
    },
    history: [] as SessionHistoryEntry[],
    achievements: [] as AchievementProgress[],
    lifecycleSnapshots: []
  };
}

function createDefaultDurableState(): DurableGameRepositoryState {
  return {
    schemaVersion: 1,
    profile: {
      lives: CommonConstants.DEFAULT_LIVES,
      gameOver: false,
      classicSessionActive: false,
      onboardingCompleted: false,
      lifecycleBanner: '',
      pendingLifecycleBanner: '',
      timedSessionBackgroundStartedAt: 0,
      stats: createPlayerStats(),
      lastSession: createClassicSnapshot(CommonConstants.DEFAULT_LIVES, 0, 0, 0, 0, 0, 0, ''),
      lastCompletedSession: createLastCompletedSessionSummary()
    },
    settings: {
      backgroundPenaltyEnabled: true,
      backgroundPolicy: 'penalize',
      timedBackgroundPolicy: 'pause',
      preferredMode: GameMode.CLASSIC,
      keepLifecycleSnapshots: true,
      hapticsEnabled: true,
      dailyReminderEnabled: false,
      dailyReminderHour: 20,
      dailyReminderMinute: 0,
      dailyReminderStatus: 'idle',
      dailyReminderToken: '',
      dailyReminderUpdatedAt: 0
    },
    history: [] as SessionHistoryEntry[],
    achievements: [] as AchievementProgress[],
    lifecycleSnapshots: []
  };
}
