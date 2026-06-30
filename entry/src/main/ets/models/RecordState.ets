/**
 * 录制状态枚举
 * 管理录屏和GIF生成的完整生命周期
 */
export enum RecordState {
  /** 就绪/空闲 */
  IDLE = 'IDLE',
  /** 录制中 */
  RECORDING = 'RECORDING',
  /** 已暂停 */
  PAUSED = 'PAUSED',
  /** 录制完成，等待编辑 */
  RECORDED = 'RECORDED',
  /** GIF生成处理中 */
  PROCESSING = 'PROCESSING',
  /** 导出完成 */
  DONE = 'DONE'
}

/**
 * 裁剪范围参数
 */
export interface TrimRange {
  /** 裁剪起点（毫秒） */
  startTime: number;
  /** 裁剪终点（毫秒） */
  endTime: number;
}

/**
 * GIF导出配置参数
 */
export interface GifConfig {
  /** 帧率 (5~20) */
  fps: number;
  /** 输出尺寸缩放比例 (0.25 / 0.5 / 0.75 / 1.0) */
  scale: number;
  /** 循环次数 (0=无限循环) */
  loopCount: number;
  /** 帧间隔时间（毫秒） */
  frameDelay: number;
}

/**
 * 默认GIF配置
 */
export const DEFAULT_GIF_CONFIG: GifConfig = {
  fps: 10,
  scale: 0.5,
  loopCount: 0,
  frameDelay: 100
};

/**
 * 历史记录条目
 */
export interface RecordHistoryItem {
  /** 唯一标识 */
  id: string;
  /** 录屏视频路径 */
  videoPath: string;
  /** GIF输出路径 */
  gifPath: string;
  /** 录屏时长（毫秒） */
  duration: number;
  /** 录屏分辨率宽度 */
  width: number;
  /** 录屏分辨率高度 */
  height: number;
  /** 创建时间戳 */
  createTime: number;
  /** GIF文件大小（字节） */
  gifFileSize: number;
  /** 使用GIF配置 */
  gifConfig: GifConfig;
}

/**
 * 可用的输出尺寸选项
 */
export const SCALE_OPTIONS: Array<{ label: string; value: number }> = [
  { label: '25%', value: 0.25 },
  { label: '50%', value: 0.5 },
  { label: '75%', value: 0.75 },
  { label: '100%', value: 1.0 }
];

/**
 * 可用的帧率选项
 */
export const FPS_OPTIONS: Array<{ label: string; value: number }> = [
  { label: '5 fps', value: 5 },
  { label: '8 fps', value: 8 },
  { label: '10 fps', value: 10 },
  { label: '15 fps', value: 15 },
  { label: '20 fps', value: 20 }
];
