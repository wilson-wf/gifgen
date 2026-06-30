import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { Logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { RecordHistoryItem } from '../models/RecordState';

const TAG = 'FileManagerService';

/**
 * 文件管理服务
 * 负责文件的创建、清理和历史记录的持久化
 */
export class FileManagerService {
  private context?: common.UIAbilityContext;

  constructor(context?: common.UIAbilityContext) {
    this.context = context;
  }

  /**
   * 设置上下文
   */
  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 获取应用文件目录
   */
  getFilesDir(): string {
    if (!this.context) {
      return '/data/local/tmp';
    }
    return this.context.filesDir;
  }

  /**
   * 获取缓存目录
   */
  getCacheDir(): string {
    if (!this.context) {
      return '/data/local/tmp';
    }
    return this.context.cacheDir;
  }

  /**
   * 确保目录存在
   */
  ensureDir(dirPath: string): void {
    if (!fileIo.accessSync(dirPath)) {
      try {
        fileIo.mkdirSync(dirPath, true);
        Logger.info(TAG, `创建目录: ${dirPath}`);
      } catch (e) {
        Logger.error(TAG, `创建目录失败: ${JSON.stringify(e)}`);
      }
    }
  }

  /**
   * 创建录屏输出文件
   */
  createRecordFile(): { path: string; fd: number } {
    const dir = this.getFilesDir();
    this.ensureDir(dir);
    const path = dir + `/screen_${Date.now()}${Constants.VIDEO_FORMAT}`;
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
    return { path, fd: file.fd };
  }

  /**
   * 创建GIF输出文件
   */
  createGifFile(): { path: string; fd: number } {
    const dir = this.getCacheDir();
    this.ensureDir(dir);
    const path = dir + `/gif_${Date.now()}${Constants.GIF_FORMAT}`;
    const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
    return { path, fd: file.fd };
  }

  /**
   * 获取文件大小
   */
  getFileSize(filePath: string): number {
    try {
      const stat = fileIo.statSync(filePath);
      return stat.size;
    } catch (e) {
      Logger.warn(TAG, `获取文件大小失败: ${filePath}`);
      return 0;
    }
  }

  /**
   * 检查文件是否存在
   */
  fileExists(filePath: string): boolean {
    try {
      return fileIo.accessSync(filePath);
    } catch (e) {
      return false;
    }
  }

  /**
   * 删除文件
   */
  deleteFile(filePath: string): boolean {
    try {
      if (fileIo.accessSync(filePath)) {
        fileIo.unlinkSync(filePath);
        Logger.info(TAG, `文件已删除: ${filePath}`);
        return true;
      }
      return true;
    } catch (e) {
      Logger.warn(TAG, `删除文件失败: ${filePath}`);
      return false;
    }
  }

  /**
   * 清理所有临时录屏文件
   */
  cleanupTempFiles(): void {
    try {
      const filesDir = this.getFilesDir();
      const list = fileIo.listFileSync(filesDir);
      for (const fileName of list) {
        if (fileName.startsWith('screen_') && fileName.endsWith(Constants.VIDEO_FORMAT)) {
          const filePath = filesDir + '/' + fileName;
          try {
            fileIo.unlinkSync(filePath);
            Logger.info(TAG, `清理临时文件: ${fileName}`);
          } catch (e) {
            // 忽略单个文件删除失败
          }
        }
      }
    } catch (e) {
      Logger.warn(TAG, `清理临时文件失败: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 保存历史记录到本地文件
   */
  saveHistory(historyItems: RecordHistoryItem[]): void {
    try {
      const filePath = this.getFilesDir() + '/' + Constants.HISTORY_FILE_NAME;
      const jsonStr = JSON.stringify(historyItems);

      if (fileIo.accessSync(filePath)) {
        fileIo.unlinkSync(filePath);
      }

      const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, jsonStr);
      fileIo.closeSync(file.fd);

      Logger.info(TAG, `历史记录已保存，共${historyItems.length}条`);
    } catch (e) {
      Logger.error(TAG, `保存历史记录失败: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 从本地文件加载历史记录
   */
  loadHistory(): RecordHistoryItem[] {
    try {
      const filePath = this.getFilesDir() + '/' + Constants.HISTORY_FILE_NAME;
      if (!fileIo.accessSync(filePath)) {
        return [];
      }

      const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(fileIo.statSync(filePath).size);
      fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file.fd);

      const jsonStr = String.fromCharCode.apply(null, new Uint8Array(buffer) as unknown as number[]);
      const items: RecordHistoryItem[] = JSON.parse(jsonStr);

      Logger.info(TAG, `历史记录已加载，共${items.length}条`);
      return items;
    } catch (e) {
      Logger.warn(TAG, `加载历史记录失败: ${JSON.stringify(e)}`);
      return [];
    }
  }

  /**
   * 获取存储使用量
   */
  getStorageUsage(): { usedMB: number; fileCount: number } {
    let usedBytes = 0;
    let fileCount = 0;
    try {
      const filesDir = this.getFilesDir();
      const list = fileIo.listFileSync(filesDir);
      for (const fileName of list) {
        const filePath = filesDir + '/' + fileName;
        try {
          const stat = fileIo.statSync(filePath);
          usedBytes += stat.size;
          fileCount++;
        } catch (e) {
          // 忽略单个文件
        }
      }
    } catch (e) {
      // 忽略
    }
    return {
      usedMB: Math.round(usedBytes / (1024 * 1024) * 10) / 10,
      fileCount
    };
  }
}
