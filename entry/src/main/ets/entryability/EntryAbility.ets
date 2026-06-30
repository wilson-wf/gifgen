import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Logger } from '../utils/Logger';

const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  private windowStage: window.WindowStage | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Logger.info(TAG, 'Application onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    Logger.info(TAG, 'onWindowStageCreate');

    this.windowStage = windowStage;

    try {
      // 设置PC窗口属性
      windowStage.getMainWindow((err, mainWindow) => {
        if (err.code) {
          Logger.error(TAG, `获取主窗口失败: ${JSON.stringify(err)}`);
          return;
        }

        // PC端窗口配置
        mainWindow.setWindowLayoutFullScreen(false)
          .then(() => {
            Logger.info(TAG, '设置非全屏布局成功');
          })
          .catch((e) => {
            Logger.warn(TAG, `设置非全屏失败: ${JSON.stringify(e)}`);
          });

        // 设置窗口大小（PC桌面端）
        mainWindow.resize(1200, 800)
          .then(() => {
            Logger.info(TAG, '设置窗口大小成功: 1200x800');
          })
          .catch((e) => {
            Logger.warn(TAG, `设置窗口大小失败: ${JSON.stringify(e)}`);
          });

        // 设置窗口标题
        mainWindow.setWindowTitle('Screen2GIF - 录屏转GIF工具')
          .then(() => {
            Logger.info(TAG, '设置窗口标题成功');
          })
          .catch((e) => {
            Logger.warn(TAG, `设置窗口标题失败: ${JSON.stringify(e)}`);
          });
      });

      // 加载主页面
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          Logger.error(TAG, `加载页面失败: ${JSON.stringify(err)}`);
          return;
        }
        Logger.info(TAG, '主页面加载成功');
      });

    } catch (e) {
      Logger.error(TAG, `窗口初始化失败: ${JSON.stringify(e)}`);
    }
  }

  onForeground(): void {
    Logger.info(TAG, 'Application onForeground');
  }

  onBackground(): void {
    Logger.info(TAG, 'Application onBackground');
  }

  onWindowStageDestroy(): void {
    Logger.info(TAG, 'onWindowStageDestroy');
    this.windowStage = null;
  }

  onDestroy(): void {
    Logger.info(TAG, 'Application onDestroy');
  }
}
