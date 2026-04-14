import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export function tryParseDurableState<T>(rawState: string | undefined, domain: number, tag: string): T | undefined {
  if (!rawState) {
    hilog.info(domain, tag, 'tryParseState skipped: empty raw state');
    return undefined;
  }

  try {
    const parsed = JSON.parse(rawState) as T;
    hilog.info(domain, tag, 'tryParseState success bytes=%{public}d', rawState.length);
    return parsed;
  } catch (error) {
    hilog.warn(domain, tag, 'tryParseState failed %{public}s', JSON.stringify(error));
    return undefined;
  }
}

export function readDurableState(storageFilePath: string, stateKey: string, domain: number, tag: string): string {
  if (!storageFilePath) {
    hilog.info(domain, tag, 'readDurableState no file path, falling back to AppStorage');
    return AppStorage.get<string>(stateKey) ?? '';
  }

  try {
    fileIo.accessSync(storageFilePath);
  } catch (error) {
    hilog.info(domain, tag, 'readDurableState file missing/unavailable %{public}s error=%{public}s',
      storageFilePath, JSON.stringify(error));
    return AppStorage.get<string>(stateKey) ?? '';
  }

  try {
    const stat = fileIo.statSync(storageFilePath);
    const size = stat.size ?? 0;
    if (size <= 0) {
      hilog.info(domain, tag, 'readDurableState file empty %{public}s', storageFilePath);
      return '';
    }

    const file = fileIo.openSync(storageFilePath, fileIo.OpenMode.READ_ONLY);
    try {
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
      hilog.info(domain, tag, 'readDurableState success path=%{public}s bytes=%{public}d', storageFilePath, readBytes);
      return result;
    } finally {
      fileIo.closeSync(file);
    }
  } catch (error) {
    hilog.warn(domain, tag, 'readDurableState failed path=%{public}s error=%{public}s',
      storageFilePath, JSON.stringify(error));
    return AppStorage.get<string>(stateKey) ?? '';
  }
}

export function writeDurableState(storageDir: string, storageFilePath: string, serializedState: string,
  domain: number, tag: string): void {
  if (!storageFilePath) {
    hilog.info(domain, tag, 'writeDurableState skipped: no file path');
    return;
  }

  try {
    fileIo.accessSync(storageDir);
  } catch (_error) {
    try {
      fileIo.mkdirSync(storageDir);
      hilog.info(domain, tag, 'writeDurableState created storage dir %{public}s', storageDir);
    } catch (_mkdirError) {
      hilog.warn(domain, tag, 'writeDurableState failed to create dir %{public}s', storageDir);
      return;
    }
  }

  try {
    const file = fileIo.openSync(storageFilePath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, serializedState);
      hilog.info(domain, tag, 'writeDurableState success path=%{public}s bytes=%{public}d',
        storageFilePath, serializedState.length);
    } finally {
      fileIo.closeSync(file);
    }
  } catch (error) {
    hilog.warn(domain, tag, 'writeDurableState failed path=%{public}s error=%{public}s',
      storageFilePath, JSON.stringify(error));
  }
}
