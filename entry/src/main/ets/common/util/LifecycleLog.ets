import CommonConstants from '../constants/CommonConstants';
import { gameRepository } from '../../data/GameRepository';
import { LifecycleEntry } from '../../data/models/GameRepositoryTypes';

export default class LifecycleLog {
  static logs: LifecycleEntry[] = [];

  static add(stage: string, message: string) {
    if (LifecycleLog.logs.length === 0) {
      LifecycleLog.logs = gameRepository.getLifecycleEntries().slice(-CommonConstants.MAX_LOGS);
    }
    const entry: LifecycleEntry = {
      capturedAt: new Date().getTime(),
      stage,
      message
    };
    LifecycleLog.logs.push(entry);
    if (LifecycleLog.logs.length > CommonConstants.MAX_LOGS) {
      LifecycleLog.logs.shift();
    }
    gameRepository.saveLifecycleSnapshot(LifecycleLog.logs);
  }

  static getAll(): LifecycleEntry[] {
    if (LifecycleLog.logs.length === 0) {
      const entries = gameRepository.getLifecycleEntries();
      if (entries.length > 0) {
        LifecycleLog.logs = entries.slice(-CommonConstants.MAX_LOGS);
      }
    }
    return LifecycleLog.logs;
  }

  static getLast(): string {
    const last = LifecycleLog.getAll()[LifecycleLog.getAll().length - 1];
    return last ? `${last.stage}: ${last.message}` : 'No logs.';
  }

  static clear() {
    LifecycleLog.logs = [];
    gameRepository.saveLifecycleSnapshot(LifecycleLog.logs);
  }
}
