import { ReminderScheduleStatus } from '../../data/models/GameRepositoryTypes';
import { harmonyReminderDriver } from './adapters/HarmonyReminderAdapter';

export interface ReminderOperationResult {
  supported: boolean;
  scheduled: boolean;
  status: ReminderScheduleStatus;
  reminderToken?: string;
  message: string;
  updatedAt: number;
}

export interface ReminderDriver {
  scheduleDaily?(hour: number, minute: number, message: string): Promise<string | undefined>;

  cancelDaily?(reminderToken?: string): Promise<void>;
}

export class DailyReminderService {
  private driver?: ReminderDriver;

  constructor(driver?: ReminderDriver) {
    this.driver = driver;
  }

  async scheduleDaily(hour: number, minute: number): Promise<ReminderOperationResult> {
    const now = new Date().getTime();
    const resolved = this.driver ?? this.resolveDriver();
    if (!resolved || !resolved.scheduleDaily) {
      return {
        supported: false,
        scheduled: false,
        status: 'unsupported',
        message: 'Reminders are unavailable on this device/runtime.',
        updatedAt: now
      };
    }

    try {
      const reminderToken = await resolved.scheduleDaily(hour, minute, 'Daily challenge is ready in Guess the Num.');
      if (!reminderToken) {
        return {
          supported: true,
          scheduled: false,
          status: 'failed',
          message: 'Could not schedule reminder. Targeted cancellation is unavailable.',
          updatedAt: now
        };
      }
      return {
        supported: true,
        scheduled: true,
        status: 'scheduled',
        reminderToken,
        message: `Daily reminder set for ${this.toTimeLabel(hour, minute)}.`,
        updatedAt: now
      };
    } catch (_error) {
      return {
        supported: true,
        scheduled: false,
        status: 'failed',
        message: 'Could not schedule reminder. Please try again.',
        updatedAt: now
      };
    }
  }

  async cancelDaily(reminderToken?: string): Promise<ReminderOperationResult> {
    const now = new Date().getTime();
    const resolved = this.driver ?? this.resolveDriver();
    if (!resolved || !resolved.cancelDaily) {
      return {
        supported: false,
        scheduled: false,
        status: 'unsupported',
        message: 'Reminders are unavailable on this device/runtime.',
        updatedAt: now
      };
    }

    if (!reminderToken) {
      return {
        supported: true,
        scheduled: false,
        status: 'failed',
        message: 'Could not cancel reminder. Targeted cancellation requires a reminder token.',
        updatedAt: now
      };
    }

    try {
      await resolved.cancelDaily(reminderToken);
      return {
        supported: true,
        scheduled: false,
        status: 'cancelled',
        message: 'Daily reminder cancelled.',
        updatedAt: now
      };
    } catch (_error) {
      return {
        supported: true,
        scheduled: false,
        status: 'failed',
        message: 'Could not cancel reminder. Please try again.',
        updatedAt: now
      };
    }
  }

  async replaceDaily(hour: number, minute: number, reminderToken?: string): Promise<ReminderOperationResult> {
    const resolved = this.driver ?? this.resolveDriver();
    if (!resolved || !resolved.scheduleDaily || !resolved.cancelDaily) {
      return {
        supported: false,
        scheduled: false,
        status: 'unsupported',
        message: 'Reminders are unavailable on this device/runtime.',
        updatedAt: new Date().getTime()
      };
    }

    if (!reminderToken) {
      return this.scheduleDaily(hour, minute);
    }

    const cancelResult = await this.cancelDaily(reminderToken);
    if (!cancelResult.supported || cancelResult.status === 'failed') {
      return {
        supported: cancelResult.supported,
        scheduled: false,
        status: cancelResult.status,
        message: cancelResult.message,
        updatedAt: new Date().getTime()
      };
    }

    return this.scheduleDaily(hour, minute);
  }

  private resolveDriver(): ReminderDriver | undefined {
    return harmonyReminderDriver;
  }

  private toTimeLabel(hour: number, minute: number): string {
    const h = `${hour}`.padStart(2, '0');
    const m = `${minute}`.padStart(2, '0');
    return `${h}:${m}`;
  }
}

export const dailyReminderService = new DailyReminderService();
