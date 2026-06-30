/**
 * 常量定义
 */
export class Constants {
  /** 应用名称 */
  static readonly APP_NAME: string = 'Screen2GIF';

  /** GIF编码中帧的延迟时间单位（10ms） */
  static readonly GIF_DELAY_UNIT: number = 10;

  /** GIF编码中的帧过渡模式：恢复到之前的状态 */
  static readonly GIF_DISPOSAL_RESTORE: number = 3;

  /** GIF编码中循环次数：0=无限循环 */
  static readonly GIF_LOOP_INFINITE: number = 0;

  /** 录屏视频输出格式 */
  static readonly VIDEO_FORMAT: string = '.mp4';

  /** GIF输出格式 */
  static readonly GIF_FORMAT: string = '.gif';

  /** 录屏默认视频码率 (bps) */
  static readonly DEFAULT_VIDEO_BITRATE: number = 10000000;

  /** 录屏默认音频采样率 */
  static readonly DEFAULT_AUDIO_SAMPLE_RATE: number = 48000;

  /** 录屏默认音频通道数 */
  static readonly DEFAULT_AUDIO_CHANNEL_COUNT: number = 2;

  /** 录屏默认音频码率 */
  static readonly DEFAULT_AUDIO_BITRATE: number = 96000;

  /** 定时器更新间隔（毫秒） */
  static readonly TIMER_INTERVAL: number = 1000;

  /** GIF处理进度最大值 */
  static readonly PROGRESS_MAX: number = 100;

  /** GIF处理进度步骤：录屏阶段 */
  static readonly PROGRESS_STEP_INIT: number = 10;

  /** GIF处理进度步骤：帧提取完成 */
  static readonly PROGRESS_STEP_EXTRACT: number = 70;

  /** GIF处理进度步骤：编码完成 */
  static readonly PROGRESS_STEP_ENCODE: number = 95;

  /** FFmpeg命令模板 */
  static readonly FFMPEG_CMD_TEMPLATE: string =
    'ffmpeg -i {input} -ss {startTime} -t {duration} -vf "fps={fps},scale={width}:{height}:flags=lanczos" {output}';

  /** 历史记录最大保存条数 */
  static readonly MAX_HISTORY_COUNT: number = 50;

  /** 历史记录持久化文件名 */
  static readonly HISTORY_FILE_NAME: string = 'record_history.json';
}
