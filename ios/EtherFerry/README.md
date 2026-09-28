# EtherFerry iOS 版（以太渡轮 · 接收端）

本目录是 Android 工程 `AndroidReceiveApplication` 的 iOS 移植版。
功能与 Android 版完全对齐：**摄像头扫描二维码 → 协议帧重组 → zlib 解压 + SHA-256 校验 → 结果展示 / 复制 / 分享 / 历史记录**。

| 项 | Android 版 | iOS 版 |
|----|-----------|--------|
| 语言 | Java + XML | Swift + SwiftUI（iOS 16+） |
| 相机 | CameraX | AVFoundation |
| 二维码识别 | ML Kit Barcode | `AVCaptureMetadataOutput`（系统原生，零依赖） |
| 数据库 | SQLiteOpenHelper | SQLite3 C API（系统自带） |
| 解压 | `java.util.zip.Inflater` | zlib C API（桥接头） |
| 校验 | `MessageDigest` SHA-256 | CryptoKit `SHA256` |
| 分享 | `Intent.createChooser` + FileProvider | `UIActivityViewController` |
| 协议 | `v:1` header/data 帧、base64、zlib、SHA-256 | **完全一致**，可与 Android/JS 发送端互通 |

**零第三方依赖**：全部使用系统框架，无需 CocoaPods / SPM。

## 目录结构（与实际文件一一对应）

```
ios/EtherFerry/
├── project.yml                     # XcodeGen 工程定义
├── ExportOptions-AdHoc.plist       # Ad Hoc 导出配置（xcodebuild -exportArchive 用）
├── ExportOptions-AppStore.plist    # App Store 导出配置
└── EtherFerry/                     # 源码目录（XcodeGen 的 sources）
    ├── App/
    │   ├── EtherFerryApp.swift     # @main 入口
    │   └── RootView.swift          # 底部两 Tab（扫描 / 历史）
    ├── Model/
    │   ├── TransferProtocol.swift  # 协议常量 + base64 + SHA-256 + zlib 解压
    │   ├── Frame.swift             # header / data 帧解析
    │   ├── FrameCollector.swift    # 帧收集重组（多帧 / 单帧 / 缺失帧）
    │   └── ScanRecord.swift        # 历史记录模型
    ├── Storage/
    │   ├── ScanDatabase.swift      # SQLite 建表（Application Support/ether_ferry.db）
    │   └── ScanRepository.swift    # 文件落盘 Documents/received + CRUD + 保留 100 条
    ├── Camera/
    │   ├── QRScanner.swift         # AVCaptureSession + 二维码识别
    │   └── CameraPreview.swift     # SwiftUI 预览容器
    ├── UI/
    │   ├── Theme.swift             # 与 Android colors.xml 一致的主题色
    │   ├── ScanViewModel.swift     # 扫描页状态机
    │   ├── ScanView.swift          # 扫描页（进度 / 缺失帧 / 结果 / 按钮）
    │   ├── HistoryView.swift       # 历史列表
    │   ├── HistoryDetailView.swift # 历史详情（文本 / 图片 / 分享 / 删除）
    │   └── ShareHelper.swift       # 系统分享面板
    └── Resources/
        ├── Info.plist              # 含 NSCameraUsageDescription 相机权限文案
        ├── EtherFerry-Bridging-Header.h
        └── Assets.xcassets/AppIcon.appiconset/   # 已生成 18 个尺寸图标
```

---

# ⚡ 零、没有 Mac，只想装到自己的 iPhone？

直接看这份文档：**[`ios/无Mac安装指南.md`](../无Mac安装指南.md)**

一句话路线：**GitHub 免费 macOS 云主机编译（本仓库已内置 `.github/workflows/build-ipa.yml`）
→ 下载未签名 IPA → Windows 用 Sideloadly + 自己的 Apple ID 重签 → 装到 iPhone**。
不需要 Mac，不需要付费开发者账号，有效期 7 天，到期一键续签。

如果你有 Mac，继续看下面第一节。

---

# 一、把工程变成可打开的 Xcode 工程（必须先做）

工程文件 `EtherFerry.xcodeproj` 由 XcodeGen 生成（可版本管理、跨平台可维护）。
**在 Mac 上执行**：

```bash
# 1. 安装 XcodeGen（只需一次）
brew install xcodegen

# 2. 把整个 ios/ 目录拷到 Mac 上，然后：
cd ios/EtherFerry
xcodegen generate

# 3. 打开工程
open EtherFerry.xcodeproj
```

> 也可以不用 XcodeGen：在 Xcode 里 `File → New → Project → iOS → App`
> （Interface 选 SwiftUI，语言 Swift，产品名 `EtherFerry`），
> 然后把 `EtherFerry/EtherFerry` 下所有文件夹拖入工程、
> 按下文"签名设置"配置即可。两种方式效果相同。

# 二、配置签名（关键步骤）

1. Xcode 左侧选中蓝色工程图标 → TARGETS → **EtherFerry** → **Signing & Capabilities**
2. 勾选 **Automatically manage signing**
3. **Team** 下拉选择你的开发者账号（没有就点 Add Account，用 Apple ID 登录）
4. 确认 **Bundle Identifier**：`cn.nordrassil.etherferry`（冲突就改成自己的）
5. 出现 `Signing certificate: Apple Development` 即成功

命令行方式：编辑 `project.yml`，把 `DEVELOPMENT_TEAM: ""` 填成你的 Team ID
（在 https://developer.apple.com/account → Membership details 里查看），然后重新 `xcodegen generate`。

# 三、运行验证

## 模拟器
Xcode 顶部设备选 iPhone 15 Pro 等模拟器 → `Cmd + R`。
模拟器没有摄像头，扫描页会提示无法访问相机，属正常现象；历史页可正常验证。

## 真机（推荐）
1. iPhone 用数据线连接 Mac，手机上点"信任"
2. Xcode 顶部设备选择你的 iPhone（首次连接 Xcode 会准备符号，等它完成）
3. `Cmd + R` 运行
4. **首次安装需在手机上信任开发者证书**：
   设置 → 通用 → VPN 与设备管理 → 找到你的开发者证书 → 点"信任"
5. 打开 App，允许相机权限，即可扫描「以太渡轮」Android/网页端发送的二维码

> 免费 Apple ID 签名 **7 天过期**，过期后重新 `Cmd + R` 一次即可继续使用。

# 四、打包 IPA

## 方式 A：Xcode 图形界面（推荐新手）

1. 顶部设备选择 **Any iOS Device (arm64)**（不能选模拟器）
2. 菜单 **Product → Archive**，等编译归档完成自动弹出 Organizer
3. Organizer → Archives → 选中本次归档 → **Distribute App**
4. 选择分发方式：
   - **Development**：仅注册过的开发设备
   - **Ad Hoc**：分发给指定 UDID 的设备（把接收人的设备 UDID 加入开发者中心）
   - **TestFlight & App Store**：上传 App Store Connect
5. 一路 Next（保持自动签名/重新签名选项）→ **Export**
6. 选择导出目录，得到 `EtherFerry.ipa` ✅

## 方式 B：命令行 xcodebuild（可写进 CI 脚本）

```bash
cd ios/EtherFerry

# 0) 如尚未生成工程
xcodegen generate

# 1) 归档（-allowProvisioningUpdates 自动管理证书/描述文件）
xcodebuild archive \
  -project EtherFerry.xcodeproj \
  -scheme EtherFerry \
  -configuration Release \
  -archivePath build/EtherFerry.xcarchive \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates

# 2) 导出 IPA（Ad Hoc 分发；先在 ExportOptions-AdHoc.plist 填 teamID）
xcodebuild -exportArchive \
  -archivePath build/EtherFerry.xcarchive \
  -exportOptionsPlist ExportOptions-AdHoc.plist \
  -exportPath build/ipa \
  -allowProvisioningUpdates

# 产物：build/ipa/EtherFerry.ipa

# App Store 版：把 -exportOptionsPlist 换成 ExportOptions-AppStore.plist
```

# 五、把 IPA 装到 iPhone 的方式

| 方式 | 适用 | 操作 |
|------|------|------|
| Xcode 直接运行 | 开发调试 | 连线 `Cmd + R`，无需 IPA |
| Ad Hoc + 分发平台 | 给指定设备装机 | 注册设备 UDID → 出 Ad Hoc 包 → 上传蒲公英(pgyer.com) / Diawi → 手机浏览器打开链接扫码安装 |
| TestFlight | 内测（最多 1 万人） | 上传 App Store Connect → TestFlight 添加测试员 → 手机装 TestFlight App 安装 |
| Finder / Apple Configurator 2 | 手动安装已签名 IPA | Mac 上把 IPA 拖到已连接的 iPhone → App 区安装 |
| App Store | 正式发布 | App Store Connect 提审（需隐私政策、截图等） |

> Ad Hoc 安装前必须把目标设备的 **UDID** 加入开发者中心 Devices 列表并更新描述文件。

# 六、账号类型与 IPA 有效期

| 账号 | 打包方式 | 有效期 | 说明 |
|------|---------|--------|------|
| 免费 Apple ID | Xcode 直装（Development） | 7 天 | 只能装自己的设备，到期重签 |
| 个人 / 公司 $99 | Ad Hoc / TestFlight / App Store | 1 年 | 常规分发 |
| 企业 $299 | In-House | 1 年 | 任意 iPhone 可装（审批严格） |

# 七、常见问题（FAQ）

| 问题 | 原因 / 解决 |
|------|-----------|
| `Signing for "EtherFerry" requires a development team` | Signing & Capabilities 未选 Team |
| 手机提示"未受信任的开发者" | 设置 → 通用 → VPN 与设备管理 → 信任证书 |
| 免费 App 7 天后打不开 | 签名过期，重新 Xcode 运行一次 |
| `Unable to install "EtherFerry"` | 设备 UDID 不在描述文件里 / iOS < 16.0 / Bundle ID 冲突 |
| 打包提示缺少 App 图标 | 确认 `AppIcon.appiconset` 完整（本工程已内置全尺寸图标） |
| 相机黑屏 | 模拟器无摄像头；真机需允许相机权限（Info.plist 已配文案） |
| 没有 Mac 怎么办 | **看 [`ios/无Mac安装指南.md`](../无Mac安装指南.md)**：GitHub Actions(macos-14) 出未签名 IPA → Sideloadly 自签装机；或 Codemagic / 云 Mac |
| 报 `z_stream` 找不到 | 确认 Build Settings 里 `SWIFT_OBJC_BRIDGING_HEADER` 指向 `EtherFerry/Resources/EtherFerry-Bridging-Header.h`，且 `OTHER_LDFLAGS` 含 `-lz` |
| 报 SQLite 符号缺失 | 确认 `OTHER_LDFLAGS` 含 `-lsqlite3`（project.yml 已配置） |

# 八、与 Android 端互通性

- 帧格式（`v:1` + `header`/`data` 帧）、base64、zlib（先按 ZLIB 格式解压，失败回退 raw DEFLATE）、
  SHA-256 校验逻辑与 Android 端 `Protocol.java` / `Frame.java` / `FrameCollector.java` 逐行对应；
- 发送端不变：直接用现有网页 / Android「以太渡轮」发送端循环播放二维码，iPhone 接收端即可收文件；
- 历史记录同样保留最近 100 条，文件存于 App 沙盒 `Documents/received/`；
- 非协议二维码（普通二维码）也能扫描并显示原文，与 Android 行为一致。
