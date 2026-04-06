import { describe, it, expect } from '@ohos/hypium';
import { harmonyReminderDriver } from '../main/ets/common/services/adapters/HarmonyReminderAdapter';

export default function harmonyReminderAdapterTest() {
  describe('harmonyReminderAdapterTest', () => {
    it('returns undefined when scheduling is unavailable', 0, async () => {
      const token = await harmonyReminderDriver.scheduleDaily!(8, 30, 'Daily challenge is ready in Guess the Num.');
      expect(token).assertEqual(undefined);
    });

    it('cancels gracefully without throwing', 0, async () => {
      await harmonyReminderDriver.cancelDaily!('ignored-token');
      expect(true).assertEqual(true);
    });
  });
}
