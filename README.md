# Screen2GIF - 鸿蒙PC录屏转GIF工具

一款面向鸿蒙PC（HarmonyOS PC/2in1）的轻量级录屏转GIF工具，帮助用户快速录制屏幕操作并导出为GIF动图。

## 功能特性

- **屏幕录制**：支持全屏录制，实时显示录制时长和状态
- **录制控制**：开始、暂停、继续、停止录制
- **视频裁剪**：设置GIF起始/结束时间点，精确到0.1秒
- **GIF生成**：将录屏片段导出为GIF，支持参数调节
- **参数调节**：帧率(5-20fps)、分辨率缩放(25%-100%)、循环次数
- **历史记录**：查看和管理近期录制的GIF

## 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| UI框架 | ArkUI / ArkTS | 鸿蒙声明式UI框架 |
| 录屏引擎 | AVScreenCaptureRecorder | 鸿蒙官方录屏API，输出MP4 |
| 视频处理 | Demuxer + ImagePacker | 视频帧提取 + GIF编码 |
| GIF编码 | ImagePacker (API 18+) | PixelMap序列编码GIF |

## 环境要求

- DevEco Studio 5.0.3.800+
- HarmonyOS SDK API 18+
- 鸿蒙PC/2in1真机（模拟器不支持录屏API）

## 项目结构

```
Screen2GIF/
├── entry/src/main/ets/
│   ├── entryability/EntryAbility.ets    # 应用入口
│   ├── pages/
│   │   ├── Index.ets                    # 主页面
│   │   ├── HistoryPage.ets              # 历史记录
│   │   └── PreviewPage.ets              # GIF预览
│   ├── services/
│   │   ├── ScreenRecorderService.ets    # 录屏服务
│   │   ├── GifGeneratorService.ets      # GIF生成服务
│   │   └── FileManagerService.ets       # 文件管理
│   ├── models/RecordState.ets           # 数据模型
│   └── utils/                           # 工具类
├── entry/src/main/resources/            # 资源文件
└── entry/src/main/module.json5          # 模块配置
```

## 快速开始

1. 使用 DevEco Studio 打开项目
2. 连接鸿蒙PC真机
3. 配置签名证书
4. 点击运行

## 权限说明

| 权限 | 用途 |
|------|------|
| ohos.permission.CAPTURE_SCREEN | 屏幕录制核心权限（系统级） |
| ohos.permission.KEEP_BACKGROUND_RUNNING | 后台持续录制 |
| ohos.permission.WRITE_IMAGEVIDEO | 保存GIF到系统相册 |

## 使用说明

1. 点击「开始录屏」启动录制
2. 操作屏幕，录制所需内容
3. 点击「停止录屏」结束录制
4. 调整裁剪范围和GIF参数
5. 点击「生成GIF」导出

## License

Apache-2.0
