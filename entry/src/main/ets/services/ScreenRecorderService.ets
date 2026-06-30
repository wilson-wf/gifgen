import { media } from '@kit.MediaKit';
import { fileIo } from '@kit.CoreFileKit';
import { display } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@ohos.base';
import { Constants } from '../utils/Constants';
import { Logger } from '../utils/Logger';
import { RecordState } from '../models/RecordState';

const TAG = 'ScreenRecorderService';

/**
 * 录屏状态回调类型
 */
export type RecorderStateCallback = (state: RecordState, extra?: string) => void;

/**
 * 录屏服务
 * 封装 AVScreenCaptureRecorder 的完整生命周期
 */
export class ScreenRecorderService {
  private screenCapture?: media.AVScreenCaptureRecorder;
  private captureFile?: fileIo.File;
  private videoPath: string = '';
  private displayInfo?: display.Display;
  private startTimestamp: number = 0;
  private stateCallback?: RecorderStateCallback;
  private timerId: number = -1;
  private durationMs: number = 0;

  constructor() {
  }

  /**
   * 设置状态变更回调
   */
  setStateCallback(callback: RecorderStateCallback): void {
    this.stateCallback = callback;
  }

  /**
   * 获取当前录制时长（毫秒）
   */
  getDuration(): number {
    if (this.durationMs > 0) {
      return this.durationMs;
    }
    if (this.startTimestamp > 0) {
      return Date.now() - this.startTimestamp;
    }
    return 0;
  }

  /**
   * 获取视频文件路径
   */
  getVideoPath(): string {
    return this.videoPath;
  }

  /**
   * 获取屏幕分辨率信息
   */
  getDisplayInfo(): display.Display | undefined {
    return this.displayInfo;
  }

  /**
   * 初始化并开始录屏
   */
  async startRecording(context: common.UIAbilityContext): Promise<void> {
    try {
      // 1. 获取屏幕信息
      this.displayInfo = display.getDefaultDisplaySync();
      if (!this.displayInfo) {
        Logger.error(TAG, '无法获取屏幕信息');
        throw new Error('无法获取屏幕信息');
      }
      Logger.info(TAG, `屏幕信息: ${this.displayInfo.width}x${this.displayInfo.height}`);

      // 2. 创建录屏文件
      this.videoPath = context.filesDir + `/screen_${Date.now()}${Constants.VIDEO_FORMAT}`;
      this.captureFile = fileIo.openSync(this.videoPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      Logger.info(TAG, `录屏文件路径: ${this.videoPath}`);

      // 3. 创建 AVScreenCaptureRecorder 实例
      this.screenCapture = await media.createAVScreenCaptureRecorder();
      if (!this.screenCapture) {
        throw new Error('创建录屏实例失败');
      }

      // 4. 注册状态回调
      this.registerCallbacks();

      // 5. 配置录屏参数
      // frameWidth 必须为64的倍数
      const frameWidth = this.displayInfo.width;
      const frameHeight = this.displayInfo.height;

      const captureConfig: media.AVScreenCaptureRecordConfig = {
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        fd: this.captureFile.fd,
        videoBitrate: Constants.DEFAULT_VIDEO_BITRATE,
        audioSampleRate: Constants.DEFAULT_AUDIO_SAMPLE_RATE,
        audioChannelCount: Constants.DEFAULT_AUDIO_CHANNEL_COUNT,
        audioBitrate: Constants.DEFAULT_AUDIO_BITRATE,
        displayId: 0,
        preset: media.AVScreenCaptureRecordPreset.SCREEN_RECORD_PRESET_H264_AAC_MP4
      };

      // 6. 初始化录屏
      await this.screenCapture.init(captureConfig);
      Logger.info(TAG, '录屏初始化完成');

      // 7. 豁免隐私窗口（应用自身窗口）
      try {
        // 获取当前窗口ID列表
        let windowIds: number[] = [];
        await this.screenCapture.skipPrivacyMode(windowIds);
      } catch (e) {
        Logger.warn(TAG, `豁免隐私窗口失败: ${JSON.stringify(e)}`);
      }

      // 8. 开始录制
      await this.screenCapture.startRecording();

      // 9. 记录开始时间并启动计时器
      this.startTimestamp = Date.now();
      this.durationMs = 0;
      this.startTimer();

      Logger.info(TAG, '录屏开始成功');
      this.stateCallback?.(RecordState.RECORDING);

    } catch (err) {
      const error = err as BusinessError;
      Logger.error(TAG, `录屏启动失败: code=${error.code}, message=${error.message}`);
      this.release();
      throw error;
    }
  }

  /**
   * 暂停录制
   */
  pauseRecording(): void {
    this.durationMs = Date.now() - this.startTimestamp;
    this.stopTimer();
    Logger.info(TAG, `录屏已暂停，已录制: ${this.durationMs}ms`);
    this.stateCallback?.(RecordState.PAUSED);
  }

  /**
   * 继续录制
   */
  resumeRecording(): void {
    this.startTimestamp = Date.now() - this.durationMs;
    this.startTimer();
    Logger.info(TAG, '录屏已继续');
    this.stateCallback?.(RecordState.RECORDING);
  }

  /**
   * 停止录屏
   */
  async stopRecording(): Promise<string> {
    try {
      if (this.screenCapture) {
        await this.screenCapture.stopRecording();
        Logger.info(TAG, '录屏停止成功');
      }

      this.stopTimer();
      const finalDuration = this.getDuration();
      this.durationMs = finalDuration;

      // 释放资源
      await this.release();

      this.stateCallback?.(RecordState.RECORDED);
      return this.videoPath;

    } catch (err) {
      const error = err as BusinessError;
      Logger.error(TAG, `停止录屏失败: code=${error.code}, message=${error.message}`);
      await this.release();
      throw error;
    }
  }

  /**
   * 注册录屏状态回调
   */
  private registerCallbacks(): void {
    if (!this.screenCapture) {
      return;
    }

    this.screenCapture.on('stateChange', async (stateCode: media.AVScreenCaptureStateCode) => {
      switch (stateCode) {
        case media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_STARTED:
          Logger.info(TAG, '录屏已开始');
          break;

        case media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_CANCELED:
          Logger.warn(TAG, '录屏被取消（权限拒绝）');
          this.stopTimer();
          await this.release();
          this.stateCallback?.(RecordState.IDLE, '录屏权限被拒绝');
          break;

        case media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_STOPPED_BY_USER:
          Logger.info(TAG, '用户通过系统胶囊停止录屏');
          this.stopTimer();
          this.durationMs = this.getDuration();
          await this.release();
          this.stateCallback?.(RecordState.RECORDED);
          break;

        case media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_INTERRUPTED_BY_OTHER:
          Logger.warn(TAG, '录屏被其他应用中断');
          this.stopTimer();
          await this.release();
          this.stateCallback?.(RecordState.IDLE, '录屏被其他应用中断');
          break;

        case media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_STOPPED_BY_CALL:
          Logger.warn(TAG, '录屏因通话中断');
          this.stopTimer();
          await this.release();
          this.stateCallback?.(RecordState.IDLE, '录屏因通话中断');
          break;

        case media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_ENTER_PRIVATE_SCENE:
          Logger.info(TAG, '进入隐私场景');
          break;

        case media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_EXIT_PRIVATE_SCENE:
          Logger.info(TAG, '退出隐私场景');
          break;

        default:
          Logger.debug(TAG, `录屏状态变更: ${stateCode}`);
          break;
      }
    });

    this.screenCapture.on('error', (err: BusinessError) => {
      Logger.error(TAG, `录屏异常: code=${err.code}, message=${err.message}`);
      this.stopTimer();
      this.stateCallback?.(RecordState.IDLE, `录屏异常: ${err.message}`);
    });
  }

  /**
   * 启动计时器
   */
  private startTimer(): void {
    this.stopTimer();
    this.timerId = setInterval(() => {
      // 通过回调通知UI更新时长
      this.stateCallback?.(RecordState.RECORDING);
    }, Constants.TIMER_INTERVAL);
  }

  /**
   * 停止计时器
   */
  private stopTimer(): void {
    if (this.timerId > 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  /**
   * 释放所有资源
   */
  private async release(): Promise<void> {
    this.stopTimer();
    try {
      if (this.screenCapture) {
        this.screenCapture.off('stateChange');
        this.screenCapture.off('error');
        await this.screenCapture.release();
        this.screenCapture = undefined;
      }
    } catch (e) {
      Logger.warn(TAG, `释放录屏实例失败: ${JSON.stringify(e)}`);
    }
    try {
      if (this.captureFile) {
        fileIo.closeSync(this.captureFile.fd);
        this.captureFile = undefined;
      }
    } catch (e) {
      Logger.warn(TAG, `关闭文件失败: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 清理临时视频文件
   */
  cleanupTempVideo(): void {
    if (this.videoPath && fileIo.accessSync(this.videoPath)) {
      try {
        fileIo.unlinkSync(this.videoPath);
        Logger.info(TAG, `已清理临时文件: ${this.videoPath}`);
      } catch (e) {
        Logger.warn(TAG, `清理临时文件失败: ${JSON.stringify(e)}`);
      }
    }
  }
}
