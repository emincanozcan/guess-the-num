import { harmonyHapticsDriver } from './adapters/HarmonyHapticsAdapter';

export type HapticEvent = 'correct' | 'wrong' | 'streak-milestone' | 'streak-complete' | 'session-complete';

export interface HapticsDriver {
  vibrate?(durationMs: number): void;

  playEffect?(effectId: string): void;
}

interface HapticPattern {
  durationMs: number;
  effectId: string;
}

export class WearableHapticsService {
  private driver?: HapticsDriver;

  constructor(driver?: HapticsDriver) {
    this.driver = driver;
  }

  play(event: HapticEvent): void {
    const resolvedDriver = this.driver ?? this.resolveDriver();
    if (!resolvedDriver) {
      return;
    }

    try {
      const pattern = this.resolvePattern(event);
      if (resolvedDriver.playEffect) {
        resolvedDriver.playEffect(pattern.effectId);
        return;
      }
      if (resolvedDriver.vibrate) {
        resolvedDriver.vibrate(pattern.durationMs);
      }
    } catch (_error) {
      // Graceful no-op for unsupported runtimes or API mismatches.
    }
  }

  private resolveDriver(): HapticsDriver | undefined {
    return harmonyHapticsDriver;
  }

  private resolvePattern(event: HapticEvent): HapticPattern {
    switch (event) {
      case 'correct':
        return { durationMs: 30, effectId: 'success' };
      case 'wrong':
        return { durationMs: 18, effectId: 'error' };
      case 'streak-milestone':
        return { durationMs: 45, effectId: 'warning' };
      case 'streak-complete':
        return { durationMs: 60, effectId: 'success_double' };
      case 'session-complete':
      default:
        return { durationMs: 50, effectId: 'complete' };
    }
  }
}

export const wearableHapticsService = new WearableHapticsService();
