import CommonConstants from '../constants/CommonConstants';

// LifecycleLog manages a simple in-memory log system
export default class LifecycleLog {

  // Static array to store log messages
  static logs: string[] = [];

  // Adds a new log message to the logs array
  // Keeps only the last 20 messages
  static add(message: string) {
    LifecycleLog.logs.push(`${message}`);

    // Keep only the last MAX_LOGS messages
    if (LifecycleLog.logs.length > CommonConstants.MAX_LOGS) {
      LifecycleLog.logs.shift();
    }
  }

  // Returns all log messages
  static getAll(): string[] {
    return LifecycleLog.logs;
  }

  // Returns the last log message, or a default message if no logs exist
  static getLast(): string {
    if (LifecycleLog.logs.length === 0) {
      return 'No logs.';
    }
    return LifecycleLog.logs[LifecycleLog.logs.length - 1];
  }

  // Clears all logs
  static clear() {
    LifecycleLog.logs = [];
  }
}