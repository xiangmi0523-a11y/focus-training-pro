# 专注力训练 Pro

手机优先的中文训练应用项目。当前版本包含六种练习、四级难度、本地训练记录和连续两次达标晋级规则。

## 重要说明
- 数据保存在当前设备/应用的本地存储中，不包含云同步。
- 本项目是训练练习工具，不是医学诊断或临床专注力评估。
- Android APK 通过 GitHub Actions 云端构建；首次构建需要几分钟。
- `android/` 目录会在云端工作流中生成，因此 ZIP 体积更小，适合手机上传。

## 本地预览（可选）
需要 Node.js：
```bash
npm install
npm run dev
```

## 只有安卓手机：上传 GitHub 并云构建 APK
1. 下载并解压这个 ZIP（文件管理器里找到 `focus-training-pro.zip`）。
2. 在 GitHub 创建一个新仓库，例如 `focus-training-pro`。建议设为 Public，便于首次操作。
3. 在仓库页面点 **Add file → Upload files**，上传解压后的项目内所有文件和文件夹。不要把 ZIP 文件本身当成项目上传。
4. 提交上传（Commit changes）。
5. 打开仓库的 **Actions** 标签页，找到 **Build Android APK** 工作流并运行；如果没有自动出现，先确认 `.github/workflows/android-apk.yml` 已上传。
6. 等待工作流变绿。点开最近一次运行，在 **Artifacts** 区域下载 `focus-training-pro-debug-apk`。
7. 解压下载的 artifact，找到 `app-debug.apk`，点击安装。安卓可能会要求允许当前浏览器/文件管理器安装未知应用；只对自己构建的 APK 开启。

## GitHub Actions 说明
工作流会安装 Node、构建 Web 资源、生成 Capacitor Android 项目并编译 Debug APK。Debug APK 适合个人测试，不是发布到应用商店的正式签名包。
