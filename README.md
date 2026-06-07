# 随手记 - 个人记账 App

## 项目说明

SwiftUI + SwiftData 开发的个人记账应用，通过 TrollStore 签名安装。

## 功能特性

- 5 个消费分类：住房、社交、吃饭、其他、抽烟
- 补账功能：可回溯录入历史日期账单
- 仪表盘：实时显示本月/本周额度与剩余
- 超支红色警示 + Taptic Engine 震动反馈
- 统计视图：红黑榜、累计结余金库、穿透下钻
- 月末自动结转累计结余
- FaceID / TouchID / 锁屏密码安全认证
- 2x2 桌面小组件
- CSV 导出备份
- 深色模式支持

## 编译方法

### 环境要求

- macOS 13+
- Xcode 15+
- XcodeGen（用于生成 .xcodeproj）

### 步骤

```bash
# 1. 安装 XcodeGen
brew install xcodegen

# 2. 克隆项目
git clone https://github.com/yuwenle905-maker/27sky.git
cd 27sky

# 3. 生成 Xcode 项目
xcodegen generate

# 4. 打开项目
open 随手记.xcodeproj

# 5. 在 Xcode 中编译
# Product → Archive → Distribute App → 选择 Ad Hoc 或直接导出 IPA
```

### TrollStore 安装

编译完成后用 TrollStore 直接安装 IPA，无需开发者证书。

## 技术栈

- SwiftUI
- SwiftData
- LocalAuthentication（FaceID/TouchID）
- WidgetKit（桌面小组件）
- UIKit（触觉反馈）
