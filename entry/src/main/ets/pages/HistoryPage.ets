import { RecordHistoryItem } from '../models/RecordState';
import { TimeUtil } from '../utils/TimeUtil';

/**
 * 历史记录页面
 * 显示所有已生成的GIF记录
 */
@Entry
@Component
struct HistoryPage {
  @State historyItems: RecordHistoryItem[] = [];

  aboutToAppear(): void {
    // 加载历史记录（实际项目中通过FileManagerService加载）
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('历史记录')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f1f5f9')
          .layoutWeight(1)

        Text(`${this.historyItems.length} 条记录`)
          .fontSize(13)
          .fontColor('#94a3b8')
      }
      .width('100%')
      .padding(16)

      Divider().color('#334155')

      // 历史列表
      if (this.historyItems.length === 0) {
        Column() {
          Text('暂无记录')
            .fontSize(16)
            .fontColor('#64748b')
            .margin({ top: 100 })

          Text('完成第一次录屏转GIF后\n记录将出现在这里')
            .fontSize(13)
            .fontColor('#475569')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.historyItems, (item: RecordHistoryItem) => {
            ListItem() {
              Row({ space: 16 }) {
                // 缩略图占位
                Column()
                  .width(80)
                  .height(60)
                  .backgroundColor('#334155')
                  .borderRadius(8)

                // 信息
                Column({ space: 4 }) {
                  Text(`GIF - ${TimeUtil.formatDuration(item.duration)}`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#f1f5f9')

                  Text(`${item.width}x${item.height} | ${TimeUtil.formatFileSize(item.gifFileSize)}`)
                    .fontSize(12)
                    .fontColor('#94a3b8')

                  Text(`${item.gifConfig.fps}fps | ${Math.round(item.gifConfig.scale * 100)}%缩放`)
                    .fontSize(11)
                    .fontColor('#64748b')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                // 时间
                Text(new Date(item.createTime).toLocaleDateString())
                  .fontSize(11)
                  .fontColor('#64748b')
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#1e293b')
              .borderRadius(10)
            }
          })
        }
        .layoutWeight(1)
        .padding(12)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0f172a')
  }
}
