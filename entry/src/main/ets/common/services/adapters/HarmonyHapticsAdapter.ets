import { HapticsDriver } from '../WearableHapticsService';

class HarmonyHapticsDriver implements HapticsDriver {
  playEffect(effectId: string): void {
    void effectId;
  }

  vibrate(durationMs: number): void {
    void durationMs;
  }
}

export const harmonyHapticsDriver: HapticsDriver = new HarmonyHapticsDriver();
