# Storage Assistant - 收纳小助手 📦
*这是一个练习项目
*除了这句和上一句，所有的内容都是TraeCN写的，包括代码和文档
一个基于Flutter的跨平台智能仓储管理应用，通过NFC技术实现物品的快速识别和高效管理。

## 🚀 项目概述

Storage Assistant是一个现代化的仓储管理解决方案，帮助用户轻松管理存储空间和物品。通过NFC技术实现快速识别，支持多媒体记录，提供直观的用户界面和流畅的操作体验。

## 📱 主要功能

### 🔍 NFC标签管理
- **标签识别**：自动读取NFC标签信息
- **标签写入**：将物品信息写入NFC标签
- **防冲突处理**：优化NFC会话管理

### 📦 容器管理
- **容器列表**：查看和管理所有存储容器
- **容器详情**：查看容器内的物品列表
- **容器创建**：通过NFC标签自动创建容器

### 📋 物品管理
- **物品添加**：支持添加新物品到指定容器
- **物品查看**：查看物品详细信息（名称、备注、图片、视频）
- **物品编辑**：修改物品信息
- **物品删除**：从系统中移除物品

### 🎯 智能导航
- **左右划动**：在物品详情页面支持左右划动切换物品
- **滑动动画**：平滑的滑动过渡效果
- **位置指示**：显示当前物品在列表中的位置

### 📷 多媒体支持
- **图片管理**：支持拍照或从相册选择图片
- **视频管理**：支持视频录制和播放
- **全屏查看**：图片和视频的全屏查看功能

## 🛠️ 技术架构

### 前端技术栈
- **Flutter 3.x**：跨平台移动应用框架
- **Dart**：编程语言
- **Material Design**：UI设计规范

### 核心依赖
| 依赖包 | 功能 |
|--------|------|
| nfc_manager | NFC功能集成 |
| video_player | 视频播放支持 |
| image_picker | 图片选择功能 |
| sqflite | 本地数据库存储 |
| path_provider | 文件路径管理 |
| uuid | 唯一标识符生成 |
| intl | 国际化支持 |
| permission_handler | 权限管理 |

### 项目结构
```
lib/
├── data/                 # 数据管理层
│   └── data_manager.dart # 数据管理服务
├── models/               # 数据模型
│   ├── item_record.dart  # 物品记录模型
│   ├── media_record.dart # 媒体记录模型
│   └── tag_record.dart   # 标签记录模型
├── services/             # 服务层
│   ├── database_service.dart # 数据库服务
│   ├── media_service.dart    # 媒体服务
│   └── nfc_service.dart      # NFC服务
├── views/                # 视图层
│   ├── home_page.dart           # 主页（容器详情）
│   ├── container_list_page.dart # 容器列表页
│   ├── item_info_page.dart      # 物品详情页
│   └── settings_page.dart       # 设置页
└── main.dart             # 应用入口
```

## 📋 系统要求

### 开发环境
- Flutter SDK 3.47（stable）、Dart 3.0+
- **完整 JDK 21**（需含 jlink；不支持 Java 25，精简版 JRE 不可用）
- Android SDK（compileSdk 36、build-tools 36.0.0、platform-tools、CMake 3.22.1）
- Android Studio / VS Code
- Git版本控制
- Windows 首次构建需开启系统"开发者模式"（符号链接支持）

### 运行环境
- Android 5.0+（NFC 功能建议 Android 8.0+）
- iOS 12.0+（需要物理设备）
- 支持NFC的移动设备

## 🚀 快速开始

### 1. 环境准备
```bash
# 克隆项目
git clone https://github.com/joseph60/StorageAssistant.git
cd StorageAssistant

# 安装依赖
flutter pub get
```

> **国内网络**：建议先设置镜像环境变量
> ```bash
> # Windows PowerShell（用户级永久生效）
> [Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL','https://storage.flutter-io.cn','User')
> [Environment]::SetEnvironmentVariable('PUB_HOSTED_URL','https://pub.flutter-io.cn','User')
> ```
> Gradle/Maven 镜像与 jcenter 清理已在工程中配置（见 [docs/技术实现文档.md](docs/技术实现文档.md) "问题6"）。

### 2. 平台初始化
```bash
# 生成平台特定文件（如需要）
flutter create .
```

### 3. 运行应用
```bash
# 连接设备后运行（先在手机上开启 USB 调试并授权）
flutter run

# 或先构建再安装
flutter build apk --debug

# 构建发布版本
flutter build apk --release    # Android
flutter build ios --release    # iOS
```

## 🔧 核心功能实现

### NFC功能优化
- 修复了NFC标签读取时的系统应用干扰问题
- 优化了NFC会话管理策略
- 实现了稳定的标签识别机制

### 容器管理系统
- 支持容器列表展示和管理
- 容器与物品的一对多关系管理
- 容器ID参数传递支持

### 物品保存逻辑
- 自动生成物品名称（格式：yyyyMMddHHmmss）
- 媒体文件检查和验证
- 错误处理和状态管理

### 数据持久化
- 使用SQLite实现本地数据存储
- 支持物品、标签和媒体的关系管理
- 提供完整的数据操作接口

### 近期修复（v1.1，2026-10）
- **滑动操作目标一致性**：物品详情页左右滑动切换后，修改/取出现在准确作用于当前展示物品（此前会误操作最初打开的物品）
- **容器删除/更新可靠性**：统一以 NFC 标签 ID（tagId）作为标签业务主键并按其匹配，修复部分容器删除、重命名与"清除所有数据"静默失败的问题
- **构建链升级**：适配 Flutter 3.47（Kotlin 2.2.20、完整 JDK 21），内置国内镜像与 jcenter 清理

## 📖 详细文档

文档存放在 `docs/` 目录下：
- [架构说明书（精简概览）](架构说明书.md) - 当前实现的架构速览
- [用户操作手册](docs/用户操作手册.md) - 完整的使用指南
- [系统设计文档](docs/系统设计文档.md) - 系统架构和设计说明
- [需求规格说明书](docs/需求规格说明书.md) - 功能需求分析
- [项目架构说明书](docs/项目架构说明书.md) - 技术架构详解
- [技术实现文档](docs/技术实现文档.md) - 技术细节与问题排查

## 🤝 贡献指南

欢迎提交Issue和Pull Request来改进项目。

### 贡献步骤
1. Fork项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开Pull Request

### 编码规范
- 遵循Dart官方编码规范
- 使用 `dartfmt` 格式化代码
- 添加必要的注释说明

## 📄 许可证

本项目采用MIT许可证，详见LICENSE文件。

## 📞 联系方式

如有问题或建议，请通过以下方式联系：
- 项目Issue：提交问题报告
- 邮箱：您的邮箱地址

---

**Storage Assistant** - 让仓储管理更智能、更高效！ 🚀
