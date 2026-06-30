/**
 * 日志工具类
 */
export class Logger {
  private static readonly DOMAIN: number = 0xFF00;

  /**
   * 打印调试日志
   */
  static debug(tag: string, message: string): void {
    console.debug(`[${tag}] ${message}`);
  }

  /**
   * 打印信息日志
   */
  static info(tag: string, message: string): void {
    console.info(`[${tag}] ${message}`);
  }

  /**
   * 打印警告日志
   */
  static warn(tag: string, message: string): void {
    console.warn(`[${tag}] ${message}`);
  }

  /**
   * 打印错误日志
   */
  static error(tag: string, message: string): void {
    console.error(`[${tag}] ${message}`);
  }
}
