import { describe, it, expect } from '@ohos/hypium';
import { DailyReminderService, ReminderDriver } from '../main/ets/common/services/DailyReminderService';
import { HapticsDriver, WearableHapticsService } from '../main/ets/common/services/WearableHapticsService';

class EmptyReminderDriver implements ReminderDriver {
}

class FailingReminderDriver implements ReminderDriver {
  async scheduleDaily(_hour: number, _minute: number, _message: string): Promise<string | undefined> {
    throw new Error('driver failure');
  }

  async cancelDaily(_reminderToken?: string): Promise<void> {
    throw new Error('driver failure');
  }
}

class WorkingReminderDriver implements ReminderDriver {
  scheduleCalls: number = 0;
  cancelCalls: number = 0;

  async scheduleDaily(_hour: number, _minute: number, _message: string): Promise<string | undefined> {
    this.scheduleCalls += 1;
    return 'reminder-1';
  }

  async cancelDaily(_reminderToken?: string): Promise<void> {
    this.cancelCalls += 1;
  }
}

class ReplaceReminderDriver implements ReminderDriver {
  calls: string[] = [];

  async scheduleDaily(_hour: number, _minute: number, _message: string): Promise<string | undefined> {
    this.calls.push('schedule');
    return 'reminder-2';
  }

  async cancelDaily(reminderToken?: string): Promise<void> {
    this.calls.push(`cancel:${reminderToken ?? ''}`);
  }
}

class CancelFailReminderDriver implements ReminderDriver {
  scheduleCalls: number = 0;
  cancelToken: string = '';

  async scheduleDaily(_hour: number, _minute: number, _message: string): Promise<string | undefined> {
    this.scheduleCalls += 1;
    return 'next-id';
  }

  async cancelDaily(reminderToken?: string): Promise<void> {
    this.cancelToken = reminderToken ?? '';
    throw new Error('cancel failed');
  }
}

class NoTokenReminderDriver implements ReminderDriver {
  async scheduleDaily(_hour: number, _minute: number, _message: string): Promise<string | undefined> {
    return undefined;
  }

  async cancelDaily(_reminderToken?: string): Promise<void> {
  }
}

class TokenlessRecoveryReminderDriver implements ReminderDriver {
  cancelCalls: number = 0;
  scheduleCalls: number = 0;

  async scheduleDaily(_hour: number, _minute: number, _message: string): Promise<string | undefined> {
    this.scheduleCalls += 1;
    return 'new-token';
  }

  async cancelDaily(_reminderToken?: string): Promise<void> {
    this.cancelCalls += 1;
  }
}

class BrokenHapticsDriver implements HapticsDriver {
  playCallCount: number = 0;

  playEffect(_effectId: string): void {
    this.playCallCount += 1;
    throw new Error('driver failure');
  }
}

export default function deviceServicesTest() {
  describe('deviceServicesTest', () => {
    it('returns unsupported result when reminder driver is missing', 0, async () => {
      const driver = new EmptyReminderDriver();
      const service = new DailyReminderService(driver);
      const result = await service.scheduleDaily(8, 0);

      expect(result.supported).assertEqual(false);
      expect(result.scheduled).assertEqual(false);
      expect(result.status).assertEqual('unsupported');
    });

    it('handles reminder driver failures without throwing', 0, async () => {
      const driver = new FailingReminderDriver();
      const service = new DailyReminderService(driver);

      const scheduleResult = await service.scheduleDaily(9, 30);
      const cancelResult = await service.cancelDaily('known-token');

      expect(scheduleResult.status).assertEqual('failed');
      expect(cancelResult.status).assertEqual('failed');
      expect(cancelResult.scheduled).assertEqual(false);
    });

    it('returns scheduled/cancelled statuses with a working reminder driver', 0, async () => {
      let scheduleCalls = 0;
      let cancelCalls = 0;
      const driver = new WorkingReminderDriver();
      const service = new DailyReminderService(driver);

      const scheduleResult = await service.scheduleDaily(21, 15);
      const cancelResult = await service.cancelDaily('reminder-1');

      scheduleCalls = driver.scheduleCalls;
      cancelCalls = driver.cancelCalls;
      expect(scheduleCalls).assertEqual(1);
      expect(cancelCalls).assertEqual(1);
      expect(scheduleResult.status).assertEqual('scheduled');
      expect(scheduleResult.scheduled).assertEqual(true);
      expect(scheduleResult.reminderToken).assertEqual('reminder-1');
      expect(cancelResult.status).assertEqual('cancelled');
      expect(cancelResult.scheduled).assertEqual(false);
    });

    it('replaces reminder by cancelling before scheduling', 0, async () => {
      const calls: string[] = [];
      const driver = new ReplaceReminderDriver();
      const service = new DailyReminderService(driver);

      const result = await service.replaceDaily(7, 45, 'existing-id');

      calls.splice(0, calls.length, ...driver.calls);
      expect(calls.length).assertEqual(2);
      expect(calls[0]).assertEqual('cancel:existing-id');
      expect(calls[1]).assertEqual('schedule');
      expect(result.status).assertEqual('scheduled');
      expect(result.scheduled).assertEqual(true);
      expect(result.reminderToken).assertEqual('reminder-2');
    });

    it('passes stored token to cancel path and does not schedule when cancel fails', 0, async () => {
      let scheduleCalls = 0;
      let cancelToken = '';
      const driver = new CancelFailReminderDriver();
      const service = new DailyReminderService(driver);

      const result = await service.replaceDaily(6, 0, 'stored-id');

      cancelToken = driver.cancelToken;
      scheduleCalls = driver.scheduleCalls;
      expect(cancelToken).assertEqual('stored-id');
      expect(scheduleCalls).assertEqual(0);
      expect(result.status).assertEqual('failed');
      expect(result.scheduled).assertEqual(false);
    });

    it('fails scheduling when driver cannot return reminder token', 0, async () => {
      const driver = new NoTokenReminderDriver();
      const service = new DailyReminderService(driver);

      const result = await service.scheduleDaily(10, 10);

      expect(result.status).assertEqual('failed');
      expect(result.scheduled).assertEqual(false);
    });

    it('supports tokenless recovery by scheduling fresh without broad cancel', 0, async () => {
      let cancelCalls = 0;
      let scheduleCalls = 0;
      const driver = new TokenlessRecoveryReminderDriver();
      const service = new DailyReminderService(driver);

      const cancelResult = await service.cancelDaily();
      const replaceResult = await service.replaceDaily(8, 5);

      cancelCalls = driver.cancelCalls;
      scheduleCalls = driver.scheduleCalls;
      expect(cancelCalls).assertEqual(0);
      expect(scheduleCalls).assertEqual(1);
      expect(cancelResult.status).assertEqual('failed');
      expect(cancelResult.scheduled).assertEqual(false);
      expect(replaceResult.status).assertEqual('scheduled');
      expect(replaceResult.scheduled).assertEqual(true);
      expect(replaceResult.reminderToken).assertEqual('new-token');
    });

    it('never throws when haptics driver is unavailable or broken', 0, () => {
      const unsupportedService = new WearableHapticsService();
      unsupportedService.play('correct');
      unsupportedService.play('session-complete');

      let playCallCount = 0;
      const driver = new BrokenHapticsDriver();
      const brokenService = new WearableHapticsService(driver);
      brokenService.play('wrong');

      playCallCount = driver.playCallCount;
      expect(playCallCount).assertEqual(1);
      expect(true).assertEqual(true);
    });
  });
}
