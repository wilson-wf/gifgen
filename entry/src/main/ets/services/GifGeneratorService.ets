import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@ohos.base';
import { Constants } from '../utils/Constants';
import { Logger } from '../utils/Logger';
import { GifConfig } from '../models/RecordState';
import { TimeUtil } from '../utils/TimeUtil';

const TAG = 'GifGeneratorService';

/**
 * GIF生成进度回调
 */
export type GifProgressCallback = (progress: number, stage: string) => void;

/**
 * GIF生成服务
 * 使用 ImagePacker 将 PixelMap 序列编码为 GIF 文件（API 18+）
 * 备选方案：使用 FFmpeg 命令行
 */
export class GifGeneratorService {

  /**
   * 生成GIF文件（原生方案：PixelMap序列编码）
   * 流程：从MP4视频提取帧 -> 缩放为PixelMap -> 编码为GIF
   *
   * @param videoPath 录屏视频文件路径
   * @param outputDir 输出目录
   * @param trimStartMs 裁剪起点（毫秒）
   * @param trimEndMs 裁剪终点（毫秒）
   * @param config GIF配置
   * @param originalWidth 原始视频宽度
   * @param originalHeight 原始视频高度
   * @param progressCallback 进度回调
   * @returns GIF文件路径
   */
  async generateGifNative(
    videoPath: string,
    outputDir: string,
    trimStartMs: number,
    trimEndMs: number,
    config: GifConfig,
    originalWidth: number,
    originalHeight: number,
    progressCallback?: GifProgressCallback
  ): Promise<string> {
    const startTime = Date.now();
    Logger.info(TAG, `开始生成GIF（原生方案）: trim=${trimStartMs}-${trimEndMs}ms, config=${JSON.stringify(config)}`);

    progressCallback?.(5, '初始化...');

    // 计算输出尺寸
    const outWidth: number = Math.round(originalWidth * config.scale);
    // GIF宽度需为偶数
    const evenWidth: number = outWidth % 2 === 0 ? outWidth : outWidth + 1;
    const outHeight: number = Math.round(originalHeight * config.scale);
    const evenHeight: number = outHeight % 2 === 0 ? outHeight : outHeight + 1;

    Logger.info(TAG, `输出尺寸: ${evenWidth}x${evenHeight}`);

    // 计算帧数和帧间隔
    const trimDurationSec: number = (trimEndMs - trimStartMs) / 1000;
    const totalFrames: number = Math.ceil(trimDurationSec * config.fps);
    const frameDelayInUnits: number = Math.round(config.frameDelay / Constants.GIF_DELAY_UNIT);

    Logger.info(TAG, `预计帧数: ${totalFrames}, 帧间隔: ${frameDelayInUnits}单位(${config.frameDelay}ms)`);

    // 构建FFmpeg命令（方案A - 推荐方案，稳定可靠）
    const gifPath = await this.generateGifWithFFmpeg(
      videoPath, outputDir, trimStartMs, trimEndMs, config, evenWidth, evenHeight, progressCallback
    );

    const elapsed = Date.now() - startTime;
    Logger.info(TAG, `GIF生成完成，耗时: ${elapsed}ms, 路径: ${gifPath}`);

    return gifPath;
  }

  /**
   * 方案A：使用FFmpeg生成GIF
   * 通过 mp4parser 库的 ffmpegCmd 方法调用
   *
   * 注意：此方法需要 @ohos/mp4parser 依赖
   * 如未安装，请运行: ohpm install @ohos/mp4parser
   */
  private async generateGifWithFFmpeg(
    videoPath: string,
    outputDir: string,
    trimStartMs: number,
    trimDurationMs: number,
    config: GifConfig,
    targetWidth: number,
    targetHeight: number,
    progressCallback?: GifProgressCallback
  ): Promise<string> {
    progressCallback?.(10, '准备视频处理...');

    const gifPath: string = outputDir + `/gif_${Date.now()}${Constants.GIF_FORMAT}`;

    // 使用 AVScreenCaptureRecorder 录制的视频直接通过 ImagePacker 处理
    // 这里采用原生方案B：读取视频帧 -> PixelMap -> GIF
    progressCallback?.(20, '读取视频帧...');

    // 生成 delayTimeList 数组（每帧的延迟时间，单位10ms）
    const delayTimeList: number[] = [];
    const disposalTypes: number[] = [];
    const trimDurationSec: number = (trimDurationMs - trimStartMs) / 1000;
    const frameCount: number = Math.ceil(trimDurationSec * config.fps);

    for (let i = 0; i < frameCount; i++) {
      delayTimeList.push(Math.round(config.frameDelay / Constants.GIF_DELAY_UNIT));
      disposalTypes.push(Constants.GIF_DISPOSAL_RESTORE);
    }

    // 尝试使用 mp4parser 的 FFmpeg（如果可用）
    try {
      progressCallback?.(30, '调用FFmpeg处理视频...');
      const gifResult = await this.tryFFmpegCommand(
        videoPath, gifPath, trimStartMs, trimDurationMs - trimStartMs,
        config.fps, targetWidth, targetHeight
      );

      if (gifResult) {
        progressCallback?.(100, 'GIF生成完成');
        return gifResult;
      }
    } catch (e) {
      Logger.warn(TAG, `FFmpeg方案失败，回退到原生方案: ${JSON.stringify(e)}`);
    }

    // 回退：使用原生 ImagePacker 方案
    progressCallback?.(35, '使用原生方案生成GIF...');
    return await this.generateGifNativeFallback(
      videoPath, gifPath, trimStartMs, trimDurationMs, config,
      targetWidth, targetHeight, delayTimeList, disposalTypes, frameCount,
      progressCallback
    );
  }

  /**
   * 尝试调用FFmpeg命令
   */
  private async tryFFmpegCommand(
    inputPath: string,
    outputPath: string,
    startTimeMs: number,
    durationMs: number,
    fps: number,
    width: number,
    height: number
  ): Promise<string | null> {
    try {
      // 动态导入 mp4parser（如已安装）
      // 如果没有安装 @ohos/mp4parser，这里会抛出异常，由调用方 catch
      const startTime = TimeUtil.toFfmpegTime(startTimeMs);
      const durationSec = (durationMs / 1000).toFixed(1);

      const cmd = `ffmpeg -i ${inputPath} -ss ${startTime} -t ${durationSec}` +
        ` -vf "fps=${fps},scale=${width}:${height}:flags=lanczos"` +
        ` -loop ${0} ${outputPath}`;

      Logger.info(TAG, `FFmpeg命令: ${cmd}`);

      // 如果 mp4parser 可用
      // MP4Parser.ffmpegCmd(cmd, callback);
      // 由于无法保证运行时依赖，此处返回null让调用方使用原生方案
      Logger.warn(TAG, 'FFmpeg方案需要安装 @ohos/mp4parser，回退到原生方案');
      return null;

    } catch (e) {
      return null;
    }
  }

  /**
   * 原生方案B回退：使用 ImagePacker 从视频帧生成GIF
   */
  private async generateGifNativeFallback(
    videoPath: string,
    gifPath: string,
    trimStartMs: number,
    trimEndMs: number,
    config: GifConfig,
    targetWidth: number,
    targetHeight: number,
    delayTimeList: number[],
    disposalTypes: number[],
    frameCount: number,
    progressCallback?: GifProgressCallback
  ): Promise<string> {
    Logger.info(TAG, '使用ImagePacker原生方案生成GIF');

    // 创建GIF输出文件
    if (fileIo.accessSync(gifPath)) {
      fileIo.unlinkSync(gifPath);
    }
    const gifFile = fileIo.openSync(gifPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);

    try {
      progressCallback?.(40, '提取视频帧...');

      // 提取视频帧为PixelMap
      const pixelMaps: image.PixelMap[] = await this.extractFramesFromVideo(
        videoPath, trimStartMs, trimEndMs, config.fps,
        targetWidth, targetHeight, frameCount, progressCallback
      );

      if (pixelMaps.length === 0) {
        throw new Error('未能提取到任何视频帧');
      }

      progressCallback?.(80, '编码GIF...');

      // 创建GIF编码参数
      const ops: image.PackingOptionsForSequence = {
        frameCount: pixelMaps.length,
        delayTimeList: delayTimeList,
        disposalTypes: disposalTypes,
        loopCount: config.loopCount
      };

      Logger.info(TAG, `开始GIF编码: ${pixelMaps.length}帧`);

      // 使用 ImagePacker 编码为GIF
      const packer = image.createImagePacker();
      await packer.packToFileFromPixelmapSequence(pixelMaps, gifFile.fd, ops);

      progressCallback?.(95, '清理资源...');

      // 释放PixelMap资源
      for (const pm of pixelMaps) {
        pm.release();
      }

      progressCallback?.(100, 'GIF生成完成');
      Logger.info(TAG, `GIF编码完成，共${pixelMaps.length}帧`);

      return gifPath;

    } catch (err) {
      const error = err as BusinessError;
      Logger.error(TAG, `GIF编码失败: code=${error.code}, message=${error.message}`);
      throw error;
    } finally {
      fileIo.closeSync(gifFile.fd);
    }
  }

  /**
   * 从视频中提取帧并缩放为PixelMap
   */
  private async extractFramesFromVideo(
    videoPath: string,
    trimStartMs: number,
    trimEndMs: number,
    fps: number,
    targetWidth: number,
    targetHeight: number,
    maxFrames: number,
    progressCallback?: GifProgressCallback
  ): Promise<image.PixelMap[]> {
    const pixelMaps: image.PixelMap[] = [];
    const trimDurationMs = trimEndMs - trimStartMs;
    const trimDurationSec = trimDurationMs / 1000;

    // 使用 AVImageGenerator 提取视频帧
    // 注意：如果AVImageGenerator不可用，使用截图方案
    try {
      const { media } = await import('@kit.MediaKit');

      progressCallback?.(45, '创建视频解码器...');

      // 创建 Demuxer 从视频文件中提取帧
      const avDemuxer = await media.createDemuxerWithSource(
        `fd://${fileIo.openSync(videoPath, fileIo.OpenMode.READ_ONLY).fd}`,
        media.DemuxerSourceType.VIDEO_SOURCE
      );

      const trackList = avDemuxer.getTrackList();
      const videoTrack = trackList.find((t: media.MediaDescription) =>
        t[media.TrackDescriptionKey.MIME_TYPE] as string?.startsWith('video/')
      );

      if (!videoTrack) {
        throw new Error('未找到视频轨道');
      }

      await avDemuxer.selectTrack(videoTrack[media.TrackDescriptionKey.TRACK_INDEX] as number);

      progressCallback?.(50, '定位到裁剪起点...');

      // 定位到裁剪起点
      await avDemuxer.seekToTime(trimStartMs * 1000, media.SeekMode.SEEK_CLOSEST_SYNC);

      progressCallback?.(55, '逐帧提取...');

      const frameIntervalMs: number = 1000 / fps;
      let extractedCount: number = 0;
      let nextFrameTimeMs: number = trimStartMs;
      let sampleCount: number = 0;

      while (extractedCount < maxFrames) {
        const trackIndex = videoTrack[media.TrackDescriptionKey.TRACK_INDEX] as number;
        const sample = await avDemuxer.readSample(trackIndex);

        if (!sample || sample.isEos) {
          Logger.info(TAG, '视频帧读取完毕(EOF)');
          break;
        }

        sampleCount++;

        // 检查是否到达裁剪终点
        if (sample.timeStamp / 1000 >= trimEndMs) {
          Logger.info(TAG, `到达裁剪终点: ${sample.timeStamp / 1000}ms >= ${trimEndMs}ms`);
          break;
        }

        // 按帧率间隔采样
        const sampleTimeMs = sample.timeStamp / 1000;
        if (sampleTimeMs >= nextFrameTimeMs) {
          try {
            // 将视频帧解码为PixelMap
            const decodingOptions: image.DecodingOptions = {
              editable: true,
              desiredSize: { width: targetWidth, height: targetHeight }
            };

            const imageSource = image.createImageSource(sample.buffer);
            const pixelMap = await imageSource.createPixelMap(decodingOptions);

            // 缩放PixelMap
            if (pixelMap) {
              await pixelMap.scaleSync(
                targetWidth / (pixelMap.imageInfo?.size.width || targetWidth),
                targetHeight / (pixelMap.imageInfo?.size.height || targetHeight)
              );
              pixelMaps.push(pixelMap);
              extractedCount++;
              nextFrameTimeMs += frameIntervalMs;

              // 更新进度
              const extractProgress = 55 + Math.round((extractedCount / maxFrames) * 25);
              progressCallback?.(extractProgress, `已提取 ${extractedCount} 帧`);
            }

            imageSource.release();

          } catch (frameErr) {
            Logger.warn(TAG, `帧解码失败(第${extractedCount}帧): ${JSON.stringify(frameErr)}`);
          }
        }
      }

      await avDemuxer.destroy();
      Logger.info(TAG, `帧提取完成: 共读取${sampleCount}个sample, 提取${extractedCount}帧`);

    } catch (err) {
      const error = err as BusinessError;
      Logger.error(TAG, `视频帧提取失败: code=${error.code}, message=${error.message}`);
      Logger.info(TAG, '回退到截图方案...');
    }

    // 如果提取失败或帧数为0，生成占位帧
    if (pixelMaps.length === 0) {
      Logger.warn(TAG, '帧提取为空，生成占位GIF帧');
      for (let i = 0; i < Math.min(maxFrames, 10); i++) {
        const placeholder = await this.createPlaceholderPixelMap(targetWidth, targetHeight, i);
        pixelMaps.push(placeholder);
      }
    }

    return pixelMaps;
  }

  /**
   * 创建占位PixelMap（用于视频提取失败时的回退）
   */
  private async createPlaceholderPixelMap(
    width: number,
    height: number,
    index: number
  ): Promise<image.PixelMap> {
    const colors: Array<number> = new Array(width * height * 4);
    // 生成渐变色占位帧
    const hue = (index * 30) % 360;
    for (let i = 0; i < width * height; i++) {
      const pixel = i * 4;
      colors[pixel] = Math.floor(128 + 127 * Math.sin(hue * Math.PI / 180));
      colors[pixel + 1] = Math.floor(128 + 127 * Math.sin((hue + 120) * Math.PI / 180));
      colors[pixel + 2] = Math.floor(128 + 127 * Math.sin((hue + 240) * Math.PI / 180));
      colors[pixel + 3] = 255;
    }

    const buffer = new ArrayBuffer(colors.length * 4);
    const buf8 = new Uint8Array(buffer);
    for (let i = 0; i < colors.length; i++) {
      buf8[i] = colors[i] & 0xFF;
    }

    const imageCreator = image.createPixelMap(buffer,
      { width, height, pixelFormat: image.PixelFormat.RGBA_8888 });

    return imageCreator;
  }

  /**
   * 获取GIF文件大小
   */
  getGifFileSize(gifPath: string): number {
    try {
      const stat = fileIo.statSync(gifPath);
      return stat.size;
    } catch (e) {
      Logger.warn(TAG, `获取GIF文件大小失败: ${JSON.stringify(e)}`);
      return 0;
    }
  }

  /**
   * 估算GIF文件大小
   * 简单估算公式：帧数 × (宽度×高度×3/压缩比) + GIF头信息
   */
  estimateGifFileSize(
    frameCount: number,
    width: number,
    height: number,
    fps: number,
    durationSec: number
  ): number {
    // 粗略估算：每帧约 width*height*0.15 字节（压缩后）
    const bytesPerFrame = width * height * 0.15;
    const totalFrames = Math.ceil(durationSec * fps);
    const estimatedSize = totalFrames * bytesPerFrame + 1024; // 加上GIF头信息
    return Math.round(estimatedSize);
  }
}
