# 没有 Mac，把 EtherFerry 装到自己的 iPhone

> **核心思路**：iOS 的编译必须经过 macOS，但 macOS 可以**租/借/用云端**的。
> 本方案用 **GitHub 免费提供的 macOS 云主机**编译出未签名 IPA，再在 Windows 上用
> **Sideloadly** 拿你自己的 Apple ID 重签，装到自己的 iPhone。
> **全程不需要 Mac，也不需要付费的 688 元/年开发者账号。**

- 花费：0 元
- 有效期：**7 天**（免费 Apple ID 限制），到期联网重签一次即可（约 1 分钟）
- 限制：只能装自己的设备；免费账号同时最多 3 个自签 App

---

## 第 1 步：准备（只做一次）

### 1.1 手机端开启「开发者模式」（iOS 16 及以上必须）
iPhone → **设置 → 隐私与安全性 → 开发者模式**（拉到最底部）→ 打开 → 重启手机 → 确认开启。

> **找不到「开发者模式」？这是正常的，不是你的手机有问题。**
> 这个开关是「隐藏项」：设备必须**先被电脑侧载过一次 App**，它才会出现在设置里。
> 所以请**先跳过这一步**，按第 2、3 步把 App 装上，装完之后它就会出现（详见文末
> [附录 A：找不到「开发者模式」怎么办](#附录-a找不到开发者模式怎么办)）。
> 另外：**iOS 15 及以下系统根本没有这个开关**，装完只需信任证书即可，直接忽略本步。

### 1.2 记下你的 Apple ID
就用你 iPhone 上登录的那个 Apple ID 即可（**不需要**加入开发者计划）。
如果开启了两步验证，准备好能接收验证码的设备。

### 1.3 Windows 电脑安装依赖（Sideloadly 的硬性要求）
必须安装 **非 Microsoft Store 版本** 的以下两个软件，装完重启电脑：

| 软件 | 下载地址 | 注意 |
|------|---------|------|
| iTunes | https://www.apple.com/itunes/download/ | 页面往下拉，选 **Windows 64 位** 的 exe；不要从微软商店装 |
| iCloud for Windows | https://support.apple.com/zh-cn/HT204283 | 同上 |

验证：打开 iTunes 能正常启动即可。若之前装过商店版，先在「设置 → 应用」里卸载干净。

---

## 第 2 步：云端编译出 IPA（三种方式任选其一）

### 方式 A：GitHub Actions（推荐，免费且已配置好）

本仓库已内置工作流文件 `.github/workflows/build-ipa.yml`，直接用。

1. 注册/登录 https://github.com
2. 点右上角 **+ → New repository**：
   - Repository name：`EtherFerry`
   - 选 **Public**（公开仓库的 Actions 分钟数不限；私有仓库 macOS 主机额度很小）
   - **不要**勾选 Add a README
   - 点 Create repository
3. 在仓库页面点 **Add file → Upload files**，把本地这两个东西拖进去上传：
   - 文件夹 `ios/EtherFerry/` **整个目录**（内含 `project.yml`、`EtherFerry/` 源码、`*.plist`）
   - 文件夹 `.github/`（内含 `workflows/build-ipa.yml`）
   - 上传后目录结构应为：
     ```
     ios/EtherFerry/project.yml
     ios/EtherFerry/EtherFerry/...
     .github/workflows/build-ipa.yml
     ```
4. 点 **Commit changes**
5. 顶部点 **Actions** 标签 → 左侧选中 **Build unsigned iOS IPA**
   - 若提示 "workflows must be enabled"，点绿色按钮 **I understand my workflows, go ahead and enable them**
6. 右侧点 **Run workflow**（下拉）→ 再点绿色 **Run workflow**
7. 等 5～10 分钟，出现绿色 ✅ 后点进这次运行记录
8. 页面底部 **Artifacts** 区域 → 点 **EtherFerry-unsigned-ipa** → 下载得到 zip
9. 解压，得到 **`EtherFerry-unsigned.ipa`** ← 这就是要装的包

> 以后改动源码后重新上传，再跑一次 workflow 即可拿到新 IPA。

### 方式 B：Codemagic（不想折腾 Git 命令时可用）

1. 打开 https://codemagic.io 用 GitHub 账号登录
2. Add application → 选刚建的仓库 → 平台选 **iOS**
3. 进入设置 → **Build** → 把 `Code signing` 设为 **Skip code signing**（关键）
4. 点 **Start new build** → 构建完成后在 Artifacts 下载 `.ipa`（若为 `.app`，把 `.app` 放进 `Payload/` 文件夹后压缩成 zip 并改名 `.ipa`）

### 方式 C：租一台云 Mac（最省心，但要花钱）

MacinCloud（https://www.macincloud.com）或 MacStadium 按小时租用（约 $1/小时），
用 Windows 远程桌面连上去，装 Xcode 后按 `ios/EtherFerry/README.md` 的方式 A 操作。
适合需要反复调试的场景。

---

## 第 3 步：Windows 上重签并安装

### 3.1 安装 Sideloadly
1. 下载 https://sideloadly.io （Windows 版）
2. 安装并以**管理员身份**运行

### 3.2 配置
1. iPhone 用**数据线**连电脑 → 手机上点「**信任此电脑**」并输入锁屏密码
2. Sideloadly 界面：
   - **Apple ID**：填你的 Apple ID 邮箱（建议用专门的备用小号更安全，但不是必须）
   - 点 **Advanced options**（高级选项）可以按需修改：
     - `Bundle ID`：默认 `cn.nordrassil.etherferry`，**保持默认即可**
     - 勾选 **Anisette** 相关选项保持默认
   - 中间区域点 **IPA** 图标，选中第 2 步下载的 `EtherFerry-unsigned.ipa`
   - 下方设备下拉框选中你的 iPhone

### 3.3 开始安装
点 **Start** → 首次会要求输入 Apple ID 密码：
> 注意：不是 Apple ID 登录密码，而是 **app 专用密码**。
> 获取方式：登录 https://appleid.apple.com → 「App 专用密码」→ 生成一串密码（形如 `xxxx-xxxx-xxxx-xxxx`），
> 把这一串粘贴进 Sideloadly。

随后输入手机收到的 6 位验证码。等待进度条走完，出现 **Done** 即安装成功，手机桌面出现 App 图标。

---

## 第 4 步：首次打开授权

1. 打开 App，若提示「**未受信任的企业级开发者**」：
   **设置 → 通用 → VPN 与设备管理** → 下面找到你的 Apple ID 邮箱 → 点 **信任**
2. iOS 16+ 若提示需要开发者模式：**设置 → 隐私与安全性 → 开发者模式** → 打开 → 重启 → 确认
   （在设置里**找不到**这个开关是正常的，见[附录 A](#附录-a找不到开发者模式怎么办)）
3. 回到 App，首次扫描时点「**允许**」使用相机，即可开始接收文件

---

## 第 5 步：7 天后如何续签（重要）

免费 Apple ID 签名的有效期是 **7 天**，到期 App 会闪退打不开。续签方式：

| 方式 | 操作 | 体验 |
|------|------|------|
| Sideloadly 重签 | 手机连电脑（或同一 WiFi 下勾选 *EnableWiFi*）→ 打开 Sideloadly → 选同一个 IPA → **Start** | 每次 1 分钟，需电脑 |
| AltServer + AltStore（推荐） | 装 AltServer（https://altstore.io）→ 用同一 Apple ID 装 AltStore 到手机 → AltStore 在手机里自动后台刷新续签 | **免电脑自动续签**，最省事 |
| 付费开发者账号 | 688 元/年，签名有效期 1 年，可用 TestFlight | 一劳永逸 |

> 续签**不会**丢失 App 数据（Bundle ID 不变），历史记录会保留。
> AltStore 要求手机和电脑在同一 WiFi，且电脑需常开；适合长期自用。

---

## 常见问题

| 现象 | 原因 / 解决 |
|------|-----------|
| Sideloadly 报 `iTunes/iCloud not found` | 装了微软商店版，卸载后装官网版，并重启电脑 |
| 报 `Incorrect Apple ID or password` | 用的是 App 专用密码，不是登录密码；见 3.3 |
| Actions 报 `xcodegen not found` | 重新跑一次 workflow；或改用方式 B |
| Actions 报签名错误 | 工作流已用 `CODE_SIGNING_ALLOWED=NO` 关闭签名，若仍报错请确认未修改 `project.yml` 的 `DEVELOPMENT_TEAM` |
| 安装成功但秒退 | 未信任证书（第 4 步）；未开开发者模式（见[附录 A](#附录-a找不到开发者模式怎么办)）；或 iOS 版本低于 **16.0** |
| 设置里搜不到「开发者模式」 | 正常，需先侧载一次 App 才会出现，见[附录 A](#附录-a找不到开发者模式怎么办) |
| 手机上搜不到设备 | 换原装/支持数据的线；解锁手机并点「信任此电脑」；iTunes 能识别到手机才行 |
| 想装给别人的 iPhone | 免费账号做不到，需付费账号走 Ad Hoc（要对方 UDID）或 TestFlight |
| 免费账号一周只能注册有限 App | 属正常限制；删掉其他自签 App 即可释放名额 |
| 相机黑屏 / 无法扫描 | 设置 → 隐私与安全性 → 相机 → 打开 EtherFerry 权限 |

---

## 附录 A：找不到「开发者模式」怎么办

### 为什么设置里没有这一项

iOS 16 起苹果把「开发者模式」设成了**隐藏开关**：设备必须**先被电脑上的开发者工具侧载过一次 App**，
系统才会把它显示出来。没装过任何侧载 App 的手机，设置里就是空的 —— 这是**正常现象**，不是故障。

### 先按系统版本对号入座

| 你的 iOS 版本 | 有没有这个开关 | 该怎么做 |
|--------------|--------------|---------|
| **iOS 15 及以下** | **没有**，也不需要 | 完全忽略，装完只需「信任证书」即可直接打开 |
| **iOS 16.0 ~ 16.3** | 有，但存在已知 bug，常常不出现 | 先升级系统（推荐），或用下面办法 1 试一次 |
| **iOS 16.4 及以上** | 有，侧载一次后必定出现 | 先装 App，装完再回来开启 |

查看版本：设置 → 通用 → 关于本机 → **软件版本**。

### 确认你找的位置对不对

- 正确路径：**设置 → 隐私与安全性 → 滚到页面最底部 → 开发者模式**
- 不是「设置 → 通用」，也不是「设置 → 开发者」（后者不存在）
- 最快办法：打开「设置」，在**顶部搜索框**直接搜「开发者模式」，搜不到就是还没激活

### 让开关出现的办法（按顺序试）

**办法 1：先装一次 App（最常用，八成到此解决）**
1. 直接按第 2、3 步把 IPA 装上（此时打不开没关系）
2. iOS 16.4+ 首次点开 App 会弹窗提示「需要开发者模式」→ 点「**打开设置**」→ 打开开关
3. 系统要求**重启** → 重启后弹窗点「**打开**」并输入锁屏密码确认
4. 回到桌面再打开 App，即可正常运行

> 若装完没弹窗，手动进「设置 → 隐私与安全性」，此时开关**已经出现在最底部**了，照上面第 3 步操作。

**办法 2：用 AltServer 触发（顺带解决续签问题）**
1. 电脑装 AltServer（https://altstore.io ，Windows 版）
2. 手机连电脑，AltServer 安装 AltStore 到手机
3. AltStore 首次安装会引导开启开发者模式；装完去「设置 → 隐私与安全性 → 开发者模式」打开
4. 之后 AltStore 会在同一 WiFi 下**自动续签**，7 天问题也一并解决

**办法 3：升级 iOS**
设置 → 通用 → 软件更新 → 升到最新版。16.0~16.3 的显示 bug 已在后续版本修复。

**办法 4：终极方案 —— 付费开发者账号走 TestFlight**
通过 **TestFlight** 安装的 App 是苹果官方认证渠道，**完全不需要开发者模式**。
如果你愿意花 688 元/年：注册 Apple Developer → App Store Connect 上传 IPA → TestFlight 添加自己为测试员 →
手机装 TestFlight App 即可安装，有效期 1 年，无需电脑续签。

### 开启后仍然闪退？

- 回到第 4 步，确认已在「设置 → 通用 → VPN 与设备管理」里点了**信任**
- 用 Sideloadly **重新装一次**（开发者模式开启前装的包需要重装）
- 确认 iOS ≥ 16.0（工程最低支持版本）
- 重启手机后再试

> 提示：开发者模式会略微降低系统安全性，随时可以在同一入口关掉，不影响已装 App 的数据。

---

## 附：不想用 GitHub 的话

把 `ios/EtherFerry` 整个目录打包发给有 Mac 的朋友，让对方执行：

```bash
brew install xcodegen
cd ios/EtherFerry
xcodegen generate
open EtherFerry.xcodeproj
```

然后在 Xcode 里 **Product → Archive → Distribute App → Development**，导出 IPA 发回给你。
之后你依然可以用 Sideloadly 装到自己的手机上。
