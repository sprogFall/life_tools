# Android 覆盖安装（签名一致）配置说明

你遇到的“不能覆盖安装、提示签名不一致”，本质原因是：**同一个包名（applicationId）下，新 APK 的签名证书和已安装版本不一致**。
Android 会直接拒绝安装更新（常见报错：`INSTALL_FAILED_UPDATE_INCOMPATIBLE`）。

本项目此前的 `release` 构建默认使用 `debug` 签名；如果你在不同机器/CI 打包，debug keystore 往往不同，导致每次产物签名变化，从而无法覆盖安装。

## 目标

让 `release` 构建始终使用同一份 keystore（稳定签名），以后版本即可正常覆盖安装并保留本地数据。

## 本地（Windows）生成并启用 keystore

1) 进入项目的 `android/app` 目录，生成 keystore（示例文件名：`upload-keystore.jks`）

```powershell
cd android\\app
keytool -genkeypair -v `
  -keystore upload-keystore.jks `
  -storetype JKS `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload
```

2) 在 `android/` 目录创建 `key.properties`

把 `android/key.properties.example` 复制为 `android/key.properties`，并按实际值填写：

```properties
storePassword=你的storePassword
keyPassword=你的keyPassword
keyAlias=upload
storeFile=app/upload-keystore.jks
```

3) 构建 release APK

```powershell
flutter build apk --release
```

## GitHub Actions（可选）

如果你用 `.github/workflows/build-apk.yml` 打包 release，务必提供固定 keystore，否则每次 Runner 生成的 debug keystore 都不同，产物无法覆盖安装。

建议在仓库 Secrets 配置以下变量：

- `ANDROID_KEYSTORE_BASE64`：keystore 文件的 base64（例如对 `upload-keystore.jks` 做 base64）
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

## 重要提醒（无法绕过）

- **只有当你仍然拥有“旧版本当时用于签名的 keystore”时**，才能让新版本对旧版本“直接覆盖安装”。  
- 如果旧版本是用另一份 keystore（或另一台机器的 debug keystore）签名的，而你已经找不到那份 keystore：  
  你只能 **卸载旧版本再安装一次**。从这一次开始保持 keystore 不变，后续就都能覆盖安装并保留数据。

