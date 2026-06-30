/**
 * 时间格式化工具类
 */
export class TimeUtil {
  /**
   * 将毫秒格式化为 mm:ss 时间字符串
   * @param ms 毫秒数
   * @returns 格式化后的时间字符串
   */
  static formatDuration(ms: number): string {
    if (ms < 0) {
      ms = 0;
    }
    const totalSeconds: number = Math.floor(ms / 1000);
    const minutes: number = Math.floor(totalSeconds / 60);
    const seconds: number = totalSeconds % 60;
    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
  }

  /**
   * 将毫秒格式化为 HH:mm:ss 时间字符串
   * @param ms 毫秒数
   * @returns 格式化后的时间字符串
   */
  static formatDurationLong(ms: number): string {
    if (ms < 0) {
      ms = 0;
    }
    const totalSeconds: number = Math.floor(ms / 1000);
    const hours: number = Math.floor(totalSeconds / 3600);
    const minutes: number = Math.floor((totalSeconds % 3600) / 60);
    const seconds: number = totalSeconds % 60;
    if (hours > 0) {
      return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
    }
    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
  }

  /**
   * 将毫秒转换为FFmpeg时间格式 HH:MM:SS.mmm
   * @param ms 毫秒数
   * @returns FFmpeg时间格式字符串
   */
  static toFfmpegTime(ms: number): string {
    if (ms < 0) {
      ms = 0;
    }
    const totalSeconds: number = ms / 1000;
    const hours: number = Math.floor(totalSeconds / 3600);
    const minutes: number = Math.floor((totalSeconds % 3600) / 60);
    const seconds: number = totalSeconds % 60;
    return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${seconds.toFixed(3).padStart(6, '0')}`;
  }

  /**
   * 将秒数转换为秒分格式文本
   * @param seconds 秒数
   * @returns 格式化文本
   */
  static formatSeconds(seconds: number): string {
    if (seconds < 60) {
      return `${seconds.toFixed(1)}秒`;
    }
    const min = Math.floor(seconds / 60);
    const sec = Math.floor(seconds % 60);
    return `${min}分${sec}秒`;
  }

  /**
   * 格式化文件大小
   * @param bytes 字节数
   * @returns 格式化后的大小文本
   */
  static formatFileSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    }
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  /**
   * 获取当前时间戳字符串
   * @returns 时间戳字符串
   */
  static getTimestampStr(): string {
    return Date.now().toString();
  }
}
