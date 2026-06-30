import { common } from '@kit.AbilityKit';
import { BusinessError } from '@ohos.base';
import { RecordState, GifConfig, DEFAULT_GIF_CONFIG, RecordHistoryItem, FPS_OPTIONS, SCALE_OPTIONS } from '../models/RecordState';
import { ScreenRecorderService, RecorderStateCallback } from '../services/ScreenRecorderService';
import { GifGeneratorService, GifProgressCallback } from '../services/GifGeneratorService';
import { FileManagerService } from '../services/FileManagerService';
import { TimeUtil } from '../utils/TimeUtil';
import { Logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';

const TAG = 'Index';

@Entry
@Component
struct Index {
  // ======== 状态变量 ========
  @State recState: RecordState = RecordState.IDLE;
  @State recordingDuration: number = 0; // 录屏时长（毫秒）
  @State trimStart: number = 0;         // 裁剪起点（毫秒）
  @State trimEnd: number = 0;           // 裁剪终点（毫秒）
  @State gifConfig: GifConfig = DEFAULT_GIF_CONFIG;
  @State processingProgress: number = 0;
  @State processingStage: string = '';
  @State exportedGifPath: string = '';
  @State errorMessage: string = '';
  @State showError: boolean = false;
  @State historyItems: RecordHistoryItem[] = [];
  @State durationUpdateTrigger: number = 0; // 触发时长显示更新

  // ======== 服务实例 ========
  private recorderService: ScreenRecorderService = new ScreenRecorderService();
  private gifService: GifGeneratorService = new GifGeneratorService();
  private fileService: FileManagerService = new FileManagerService();
  private context?: common.UIAbilityContext;
  private videoWidth: number = 0;
  private videoHeight: number = 0;
  private videoPath: string = '';

  aboutToAppear(): void {
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (this.context) {
      this.fileService.setContext(this.context);
      this.historyItems = this.fileService.loadHistory();
    }
    this.setupRecorderCallback();
  }

  aboutToDisappear(): void {
    Logger.info(TAG, '页面销毁');
  }

  // ======== 设置录屏回调 ========
  private setupRecorderCallback(): void {
    this.recorderService.setStateCallback((state: RecordState, extra?: string) => {
      // 在主线程更新UI
      this.recState = state;
      if (state === RecordState.RECORDING) {
        // 触发时长更新
        this.durationUpdateTrigger++;
      }
      if (extra) {
        this.errorMessage = extra;
        this.showError = true;
      }
    } as RecorderStateCallback);
  }

  // ======== 开始录屏 ========
  async startRecording(): Promise<void> {
    if (!this.context) {
      this.showErrorMessage('应用上下文未初始化');
      return;
    }

    try {
      this.recordingDuration = 0;
      this.trimStart = 0;
      this.trimEnd = 0;
      this.errorMessage = '';
      this.showError = false;

      await this.recorderService.startRecording(this.context);

      // 获取录屏分辨率
      const displayInfo = this.recorderService.getDisplayInfo();
      if (displayInfo) {
        this.videoWidth = displayInfo.width;
        this.videoHeight = displayInfo.height;
      }

      // 启动UI更新定时器
      this.startDurationTimer();

    } catch (err) {
      const error = err as BusinessError;
      this.showErrorMessage(`录屏启动失败: ${error.message || '请确认已授予录屏权限'}`);
      Logger.error(TAG, `录屏启动失败: ${JSON.stringify(err)}`);
    }
  }

  // ======== 暂停/继续 ========
  togglePause(): void {
    if (this.recState === RecordState.RECORDING) {
      this.recorderService.pauseRecording();
      this.stopDurationTimer();
    } else if (this.recState === RecordState.PAUSED) {
      this.recorderService.resumeRecording();
      this.startDurationTimer();
    }
  }

  // ======== 停止录屏 ========
  async stopRecording(): Promise<void> {
    try {
      this.stopDurationTimer();
      this.recordingDuration = this.recorderService.getDuration();
      this.videoPath = await this.recorderService.stopRecording();
      this.trimEnd = this.recordingDuration;
      this.recState = RecordState.RECORDED;

      Logger.info(TAG, `录屏完成: ${this.recordingDuration}ms, 路径: ${this.videoPath}`);
    } catch (err) {
      const error = err as BusinessError;
      this.showErrorMessage(`停止录屏失败: ${error.message}`);
    }
  }

  // ======== 生成GIF ========
  async generateGif(): Promise<void> {
    if (!this.context || !this.videoPath) {
      this.showErrorMessage('请先完成录屏');
      return;
    }

    if (this.trimEnd <= this.trimStart) {
      this.showErrorMessage('裁剪结束时间必须大于开始时间');
      return;
    }

    this.recState = RecordState.PROCESSING;
    this.processingProgress = 0;
    this.processingStage = '准备中...';

    try {
      const gifPath = await this.gifService.generateGifNative(
        this.videoPath,
        this.fileService.getCacheDir(),
        this.trimStart,
        this.trimEnd,
        this.gifConfig,
        this.videoWidth,
        this.videoHeight,
        (progress: number, stage: string) => {
          this.processingProgress = progress;
          this.processingStage = stage;
        } as GifProgressCallback
      );

      this.exportedGifPath = gifPath;
      this.recState = RecordState.DONE;

      // 保存到历史记录
      this.saveToHistory(gifPath);

      Logger.info(TAG, `GIF导出成功: ${gifPath}`);

    } catch (err) {
      const error = err as BusinessError;
      this.showErrorMessage(`GIF生成失败: ${error.message}`);
      this.recState = RecordState.RECORDED;
    }
  }

  // ======== 保存历史记录 ========
  private saveToHistory(gifPath: string): void {
    const historyItem: RecordHistoryItem = {
      id: Date.now().toString(),
      videoPath: this.videoPath,
      gifPath: gifPath,
      duration: this.trimEnd - this.trimStart,
      width: this.videoWidth,
      height: this.videoHeight,
      createTime: Date.now(),
      gifFileSize: this.gifService.getGifFileSize(gifPath),
      gifConfig: { ...this.gifConfig }
    };

    this.historyItems.unshift(historyItem);
    // 限制最大条数
    if (this.historyItems.length > Constants.MAX_HISTORY_COUNT) {
      this.historyItems = this.historyItems.slice(0, Constants.MAX_HISTORY_COUNT);
    }
    this.fileService.saveHistory(this.historyItems);
  }

  // ======== 重新录制 ========
  resetToIdle(): void {
    this.recState = RecordState.IDLE;
    this.recordingDuration = 0;
    this.trimStart = 0;
    this.trimEnd = 0;
    this.processingProgress = 0;
    this.exportedGifPath = '';
    this.errorMessage = '';
    this.showError = false;
  }

  // ======== 时长更新定时器 ========
  private durationTimerId: number = -1;

  private startDurationTimer(): void {
    this.stopDurationTimer();
    this.durationTimerId = setInterval(() => {
      this.recordingDuration = this.recorderService.getDuration();
      this.durationUpdateTrigger++;
    }, 200);
  }

  private stopDurationTimer(): void {
    if (this.durationTimerId > 0) {
      clearInterval(this.durationTimerId);
      this.durationTimerId = -1;
    }
  }

  // ======== 错误处理 ========
  private showErrorMessage(msg: string): void {
    this.errorMessage = msg;
    this.showError = true;
  }

  // ======== 格式化裁剪时间 ========
  formatTrimTime(ms: number): string {
    return TimeUtil.formatDuration(ms);
  }

  // ======== 计算预计帧数 ========
  getEstimatedFrames(): number {
    const durationSec = (this.trimEnd - this.trimStart) / 1000;
    return Math.ceil(durationSec * this.gifConfig.fps);
  }

  // ======== 构建UI ========
  build() {
    Row() {
      // ======== 左侧控制面板 ========
      Column({ space: 16 }) {
        // 应用标题
        Text('Screen2GIF')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#38bdf8')
          .margin({ top: 8 })

        Text('鸿蒙PC录屏转GIF工具')
          .fontSize(13)
          .fontColor('#94a3b8')
          .margin({ bottom: 16 })

        Divider().color('#334155')

        // 录制控制区
        this.RecordControlSection()

        Divider().color('#334155')

        // 裁剪设置区（录制完成后显示）
        if (this.recState === RecordState.RECORDED || this.recState === RecordState.PROCESSING || this.recState === RecordState.DONE) {
          this.TrimSettingsSection()
          Divider().color('#334155')
        }

        // GIF参数设置区
        this.GifSettingsSection()

        Divider().color('#334155')

        // 快捷键提示
        this.ShortcutsSection()
      }
      .width('320px')
      .height('100%')
      .padding({ left: 24, right: 24, top: 16, bottom: 16 })
      .backgroundColor('#1e293b')
      .borderRadius({ topLeft: 0, topRight: 16, bottomLeft: 0, bottomRight: 16 })

      // ======== 右侧内容区 ========
      Column() {
        if (this.recState === RecordState.IDLE) {
          // 空闲状态 - 显示欢迎信息
          this.IdleContentSection()
        } else if (this.recState === RecordState.RECORDING) {
          // 录制中 - 显示实时信息
          this.RecordingContentSection()
        } else if (this.recState === RecordState.PAUSED) {
          // 暂停中
          this.PausedContentSection()
        } else if (this.recState === RecordState.RECORDED) {
          // 录制完成 - 显示裁剪预览
          this.RecordedContentSection()
        } else if (this.recState === RecordState.PROCESSING) {
          // GIF生成中
          this.ProcessingContentSection()
        } else if (this.recState === RecordState.DONE) {
          // 导出完成
          this.DoneContentSection()
        }
      }
      .layoutWeight(1)
      .height('100%')
      .padding(24)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0f172a')
  }

  // ======== 录制控制区 ========
  @Builder
  RecordControlSection() {
    Column({ space: 12 }) {
      Text('录制控制')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f1f5f9')
        .width('100%')

      if (this.recState === RecordState.IDLE) {
        // 开始录屏按钮
        Button('开始录屏')
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#ef4444')
          .fontColor('#ffffff')
          .borderRadius(24)
          .onClick(() => { this.startRecording(); })
      } else if (this.recState === RecordState.RECORDING || this.recState === RecordState.PAUSED) {
        // 录制中/暂停 状态按钮组
        Row({ space: 12 }) {
          Button(this.recState === RecordState.RECORDING ? '暂停' : '继续')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .backgroundColor('#f59e0b')
            .fontColor('#ffffff')
            .borderRadius(22)
            .onClick(() => { this.togglePause(); })

          Button('停止录屏')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#ef4444')
            .fontColor('#ffffff')
            .borderRadius(22)
            .onClick(() => { this.stopRecording(); })
        }
        .width('100%')

        // 录制时长
        Text(TimeUtil.formatDurationLong(this.recordingDuration))
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.recState === RecordState.RECORDING ? '#ef4444' : '#f59e0b')
          .fontVariant([FontVariant.TabularFigures])
          .margin({ top: 8 })

        // 录制分辨率
        if (this.videoWidth > 0) {
          Text(`${this.videoWidth} x ${this.videoHeight}`)
            .fontSize(12)
            .fontColor('#64748b')
        }

        // 录制状态指示
        if (this.recState === RecordState.RECORDING) {
          Row({ space: 8 }) {
            Text('')
              .width(10).height(10)
              .borderRadius(5)
              .backgroundColor('#ef4444')
            Text('录制中...')
              .fontSize(13)
              .fontColor('#ef4444')
          }
        } else {
          Row({ space: 8 }) {
            Text('')
              .width(10).height(10)
              .borderRadius(5)
              .backgroundColor('#f59e0b')
            Text('已暂停')
              .fontSize(13)
              .fontColor('#f59e0b')
          }
        }
      } else if (this.recState === RecordState.PROCESSING) {
        // 处理中 - 显示进度
        Progress({ value: this.processingProgress, total: 100, type: ProgressType.Ring })
          .width(60).height(60)
          .color('#38bdf8')

        Text(`${this.processingProgress}%`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#38bdf8')

        Text(this.processingStage)
          .fontSize(12)
          .fontColor('#94a3b8')
      } else if (this.recState === RecordState.DONE) {
        Button('重新录制')
          .width('100%')
          .height(48)
          .fontSize(16)
          .backgroundColor('#334155')
          .fontColor('#f1f5f9')
          .borderRadius(24)
          .onClick(() => { this.resetToIdle(); })
      }
    }
    .width('100%')
  }

  // ======== 裁剪设置区 ========
  @Builder
  TrimSettingsSection() {
    Column({ space: 10 }) {
      Text('裁剪范围')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#a78bfa')
        .width('100%')

      // 起点滑块
      Row() {
        Text('起点')
          .fontSize(12)
          .fontColor('#94a3b8')
          .width(36)
        Slider({
          value: this.trimStart,
          min: 0,
          max: Math.max(this.recordingDuration, 1),
          step: 100
        })
          .layoutWeight(1)
          .blockColor('#a78bfa')
          .trackColor('#334155')
          .selectedColor('#a78bfa')
          .onChange((value: number) => {
            if (value >= this.trimEnd) {
              this.trimStart = Math.max(0, this.trimEnd - 100);
            } else {
              this.trimStart = value;
            }
          })
        Text(this.formatTrimTime(this.trimStart))
          .fontSize(11)
          .fontColor('#94a3b8')
          .width(48)
          .textAlign(TextAlign.End)
      }
      .width('100%')

      // 终点滑块
      Row() {
        Text('终点')
          .fontSize(12)
          .fontColor('#94a3b8')
          .width(36)
        Slider({
          value: this.trimEnd,
          min: 0,
          max: Math.max(this.recordingDuration, 1),
          step: 100
        })
          .layoutWeight(1)
          .blockColor('#a78bfa')
          .trackColor('#334155')
          .selectedColor('#a78bfa')
          .onChange((value: number) => {
            if (value <= this.trimStart) {
              this.trimEnd = Math.min(this.recordingDuration, this.trimStart + 100);
            } else {
              this.trimEnd = value;
            }
          })
        Text(this.formatTrimTime(this.trimEnd))
          .fontSize(11)
          .fontColor('#94a3b8')
          .width(48)
          .textAlign(TextAlign.End)
      }
      .width('100%')

      // 裁剪信息
      Text(`选中: ${this.formatTrimTime(this.trimEnd - this.trimStart)}`)
        .fontSize(11)
        .fontColor('#64748b')
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#1e293b')
    .borderRadius(12)
  }

  // ======== GIF参数设置区 ========
  @Builder
  GifSettingsSection() {
    Column({ space: 12 }) {
      Text('GIF参数')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#38bdf8')
        .width('100%')

      // 帧率选择
      Text(`帧率: ${this.gifConfig.fps} fps`)
        .fontSize(12)
        .fontColor('#94a3b8')
        .width('100%')
      Row({ space: 6 }) {
        ForEach(FPS_OPTIONS, (item: { label: string; value: number }) => {
          Button(item.label)
            .fontSize(11)
            .height(32)
            .padding({ left: 12, right: 12 })
            .backgroundColor(this.gifConfig.fps === item.value ? '#38bdf8' : '#334155')
            .fontColor(this.gifConfig.fps === item.value ? '#ffffff' : '#94a3b8')
            .borderRadius(16)
            .onClick(() => {
              this.gifConfig.fps = item.value;
              // 帧间隔自动调整
              this.gifConfig.frameDelay = Math.round(1000 / item.value);
            })
        })
      }
      .width('100%')

      // 尺寸选择
      Text(`尺寸: ${Math.round(this.gifConfig.scale * 100)}%`)
        .fontSize(12)
        .fontColor('#94a3b8')
        .width('100%')
      Row({ space: 6 }) {
        ForEach(SCALE_OPTIONS, (item: { label: string; value: number }) => {
          Button(item.label)
            .fontSize(11)
            .height(32)
            .padding({ left: 12, right: 12 })
            .backgroundColor(Math.abs(this.gifConfig.scale - item.value) < 0.01 ? '#38bdf8' : '#334155')
            .fontColor(Math.abs(this.gifConfig.scale - item.value) < 0.01 ? '#ffffff' : '#94a3b8')
            .borderRadius(16)
            .onClick(() => {
              this.gifConfig.scale = item.value;
            })
        })
      }
      .width('100%')

      // 生成按钮
      if (this.recState === RecordState.RECORDED) {
        Button('生成GIF')
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#38bdf8')
          .fontColor('#ffffff')
          .borderRadius(24)
          .margin({ top: 8 })
          .onClick(() => { this.generateGif(); })
      }
    }
    .width('100%')
  }

  // ======== 快捷键提示 ========
  @Builder
  ShortcutsSection() {
    Column({ space: 4 }) {
      Text('快捷操作')
        .fontSize(11)
        .fontColor('#64748b')
        .width('100%')
      Text('Ctrl+Shift+R  开始/停止录屏')
        .fontSize(10)
        .fontColor('#475569')
      Text('Ctrl+Shift+P  暂停/继续')
        .fontSize(10)
        .fontColor('#475569')
    }
    .width('100%')
    .margin({ top: 8 })
  }

  // ======== 右侧内容区 - 各状态 ========

  @Builder
  IdleContentSection() {
    Column({ space: 24 }) {
      // 大图标区域
      Text('S2G')
        .fontSize(72)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1e293b')
        .backgroundColor('#334155')
        .width(140)
        .height(140)
        .borderRadius(32)
        .textAlign(TextAlign.Center)

      Text('点击左侧「开始录屏」按钮\n录制屏幕操作，一键生成GIF动图')
        .fontSize(16)
        .fontColor('#94a3b8')
        .textAlign(TextAlign.Center)
        .lineHeight(28)

      // 使用步骤
      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Text('1')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#38bdf8')
            .width(28).height(28)
            .borderRadius(14)
            .textAlign(TextAlign.Center)
            .backgroundColor('#1e3a5f')
          Text('点击「开始录屏」启动录制')
            .fontSize(14).fontColor('#94a3b8')
        }
        Row({ space: 12 }) {
          Text('2')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#a78bfa')
            .width(28).height(28)
            .borderRadius(14)
            .textAlign(TextAlign.Center)
            .backgroundColor('#2e1f5e')
          Text('操作屏幕，录制所需内容')
            .fontSize(14).fontColor('#94a3b8')
        }
        Row({ space: 12 }) {
          Text('3')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#38bdf8')
            .width(28).height(28)
            .borderRadius(14)
            .textAlign(TextAlign.Center)
            .backgroundColor('#1e3a5f')
          Text('点击「停止录屏」结束录制')
            .fontSize(14).fontColor('#94a3b8')
        }
        Row({ space: 12 }) {
          Text('4')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#a78bfa')
            .width(28).height(28)
            .borderRadius(14)
            .textAlign(TextAlign.Center)
            .backgroundColor('#2e1f5e')
          Text('调整参数，点击「生成GIF」导出')
            .fontSize(14).fontColor('#94a3b8')
        }
      }
      .alignItems(HorizontalAlign.Start)

      // 历史记录快捷入口
      if (this.historyItems.length > 0) {
        Text(`已有 ${this.historyItems.length} 条历史记录`)
          .fontSize(12)
          .fontColor('#64748b')
          .margin({ top: 24 })
      }
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  RecordingContentSection() {
    Column({ space: 16 }) {
      Text('录制中')
        .fontSize(48)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ef4444')

      Text(TimeUtil.formatDurationLong(this.recordingDuration))
        .fontSize(64)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f1f5f9')
        .fontVariant([FontVariant.TabularFigures])

      Text('系统正在录制您的屏幕内容...')
        .fontSize(14)
        .fontColor('#94a3b8')

      if (this.videoWidth > 0) {
        Text(`分辨率: ${this.videoWidth} x ${this.videoHeight}`)
          .fontSize(12)
          .fontColor('#64748b')
      }

      // 录制动画指示
      Row({ space: 8 }) {
        ForEach([1, 2, 3], (item: number) => {
          Text('')
            .width(12).height(12)
            .borderRadius(6)
            .backgroundColor('#ef4444')
            .opacity(item % 2 === 0 ? 0.5 : 1)
        })
      }
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  PausedContentSection() {
    Column({ space: 16 }) {
      Text('已暂停')
        .fontSize(48)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f59e0b')

      Text(TimeUtil.formatDurationLong(this.recordingDuration))
        .fontSize(64)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f1f5f9')
        .fontVariant([FontVariant.TabularFigures])

      Text('点击左侧「继续」按钮恢复录制')
        .fontSize(14)
        .fontColor('#94a3b8')
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  RecordedContentSection() {
    Column({ space: 20 }) {
      Text('录制完成')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#34d399')

      Row({ space: 32 }) {
        Column({ space: 4 }) {
          Text('时长')
            .fontSize(12).fontColor('#64748b')
          Text(TimeUtil.formatDuration(this.recordingDuration))
            .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#f1f5f9')
        }
        Column({ space: 4 }) {
          Text('分辨率')
            .fontSize(12).fontColor('#64748b')
          Text(`${this.videoWidth}x${this.videoHeight}`)
            .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#f1f5f9')
        }
        Column({ space: 4 }) {
          Text('预计帧数')
            .fontSize(12).fontColor('#64748b')
          Text(`${this.getEstimatedFrames()}`)
            .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#f1f5f9')
        }
      }

      Text('请在左侧调整裁剪范围和GIF参数，\n然后点击「生成GIF」按钮')
        .fontSize(14)
        .fontColor('#94a3b8')
        .textAlign(TextAlign.Center)
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ProcessingContentSection() {
    Column({ space: 24 }) {
      Text('正在生成GIF...')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#38bdf8')

      Progress({ value: this.processingProgress, total: 100, type: ProgressType.Ring })
        .width(100).height(100)
        .color('#38bdf8')

      Text(`${this.processingProgress}%`)
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f1f5f9')

      Text(this.processingStage)
        .fontSize(14)
        .fontColor('#94a3b8')
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  DoneContentSection() {
    Column({ space: 20 }) {
      Text('导出成功')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor('#34d399')

      // GIF信息
      Column({ space: 8 }) {
        Row({ space: 12 }) {
          Text('GIF路径:')
            .fontSize(13).fontColor('#64748b')
          Text(this.exportedGifPath)
            .fontSize(13).fontColor('#38bdf8')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        // 文件大小
        Row({ space: 12 }) {
          Text('文件大小:')
            .fontSize(13).fontColor('#64748b')
          Text(TimeUtil.formatFileSize(this.gifService.getGifFileSize(this.exportedGifPath)))
            .fontSize(13).fontColor('#f1f5f9')
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#1e293b')
      .borderRadius(12)
    }
    .alignItems(HorizontalAlign.Center)
  }
}
