import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion, fileIo } from '@kit.CoreFileKit';
import { gameRepository } from '../data/GameRepository';
import { GameRepositoryBackupPayload } from '../data/models/GameRepositoryTypes';

const DOMAIN = 0x0000;
const TAG = 'EntryBackupAbility';
const BACKUP_FILE = 'repository_backup.json';

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup() {
    const backupPath = this.resolveBackupPath();
    if (!backupPath) {
      return;
    }

    try {
      const payload = JSON.stringify(gameRepository.exportForBackup());
      this.writePayload(backupPath, payload);
      hilog.info(DOMAIN, TAG, 'backup written %{public}s', backupPath);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'backup skipped %{public}s', JSON.stringify(error));
    }
  }

  async onRestore(bundleVersion: BundleVersion) {
    hilog.info(DOMAIN, TAG, 'onRestore %{public}s', JSON.stringify(bundleVersion));
    const backupPath = this.resolveBackupPath();
    if (!backupPath) {
      return;
    }

    const payloadText = this.readPayload(backupPath);
    if (!payloadText) {
      return;
    }

    const payload = this.parsePayload(payloadText);
    if (!payload) {
      return;
    }

    gameRepository.importFromBackup(payload);
  }

  private resolveBackupPath(): string {
    const backupDir = this.context?.backupDir;
    if (!backupDir) {
      hilog.warn(DOMAIN, TAG, 'backupDir unavailable');
      return '';
    }

    try {
      fileIo.accessSync(backupDir);
    } catch (_error) {
      try {
        fileIo.mkdirSync(backupDir);
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'backupDir not accessible %{public}s', JSON.stringify(error));
        return '';
      }
    }

    return `${backupDir}/${BACKUP_FILE}`;
  }

  private writePayload(path: string, payload: string): void {
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, payload);
      } finally {
        fileIo.closeSync(file);
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'writePayload failed %{public}s', JSON.stringify(error));
    }
  }

  private readPayload(path: string): string {
    try {
      fileIo.accessSync(path);
    } catch (_error) {
      return '';
    }

    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      try {
        const stat = fileIo.statSync(path);
        const size = stat.size ?? 0;
        if (size <= 0) {
          return '';
        }

        const buffer = new ArrayBuffer(size);
        const readBytes = fileIo.readSync(file.fd, buffer);
        if (readBytes <= 0) {
          return '';
        }
        let result = '';
        const bytes = new Uint8Array(buffer);
        let index = 0;
        while (index < readBytes) {
          result += String.fromCharCode(bytes[index]);
          index += 1;
        }
        return result;
      } finally {
        fileIo.closeSync(file);
      }
    } catch (_error) {
      return '';
    }
  }

  private parsePayload(rawPayload: string): GameRepositoryBackupPayload | undefined {
    try {
      const parsed = JSON.parse(rawPayload) as GameRepositoryBackupPayload;
      if (!parsed || !parsed.repository || typeof parsed.schemaVersion !== 'number') {
        return undefined;
      }
      return parsed;
    } catch (_error) {
      hilog.warn(DOMAIN, TAG, 'invalid backup payload');
      return undefined;
    }
  }
}
