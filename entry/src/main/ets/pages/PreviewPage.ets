import { RecordHistoryItem } from '../models/RecordState';
import { TimeUtil } from '../utils/TimeUtil';

/**
 * GIF预览页面
 * 预览生成的GIF动图
 */
@Entry
@Component
struct PreviewPage {
  @State historyItem: RecordHistoryItem | null = null;
  @State isLoading: boolean = true;

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('GIF预览')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f1f5f9')
          .layoutWeight(1)
      }
      .width('100%')
      .padding(16)

      Divider().color('#334155')

      // 预览区
      if (this.historyItem) {
        Column({ space: 24 }) {
          // GIF展示区（占位）
          Column()
            .width(640)
            .height(400)
            .backgroundColor('#1e293b')
            .borderRadius(12)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center) {
            if (this.isLoading) {
              Text('加载中...')
                .fontSize(16)
                .fontColor('#94a3b8')
            } else {
              Text('GIF预览')
                .fontSize(20)
                .fontColor('#64748b')
            }
          }

          // GIF信息
          Column({ space: 8 }) {
            Row({ space: 24 }) {
              Column({ space: 4 }) {
                Text('时长')
                  .fontSize(12).fontColor('#64748b')
                Text(TimeUtil.formatDuration(this.historyItem!.duration))
                  .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#f1f5f9')
              }
              Column({ space: 4 }) {
                Text('尺寸')
                  .fontSize(12).fontColor('#64748b')
                Text(`${this.historyItem!.width}x${this.historyItem!.height}`)
                  .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#f1f5f9')
              }
              Column({ space: 4 }) {
                Text('大小')
                  .fontSize(12).fontColor('#64748b')
                Text(TimeUtil.formatFileSize(this.historyItem!.gifFileSize))
                  .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#f1f5f9')
              }
              Column({ space: 4 }) {
                Text('帧率')
                  .fontSize(12).fontColor('#64748b')
                Text(`${this.historyItem!.gifConfig.fps} fps`)
                  .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#f1f5f9')
              }
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#1e293b')
          .borderRadius(12)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding(24)
      } else {
        Column() {
          Text('无预览内容')
            .fontSize(16)
            .fontColor('#64748b')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0f172a')
  }
}
