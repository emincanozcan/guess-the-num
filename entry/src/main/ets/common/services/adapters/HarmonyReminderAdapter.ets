import { ReminderDriver } from '../DailyReminderService';

class HarmonyReminderDriver implements ReminderDriver {
  async scheduleDaily(hour: number, minute: number, message: string): Promise<string | undefined> {
    void hour;
    void minute;
    void message;
    return undefined;
  }

  async cancelDaily(reminderToken?: string): Promise<void> {
    void reminderToken;
  }
}

export const harmonyReminderDriver: ReminderDriver = new HarmonyReminderDriver();
