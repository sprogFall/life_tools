# GitHub Actions Build APK Workflow 更新

## 更新时间
2024年（当前分支：feat/components-zh-cn）

## 更新内容

### 新增 dev 分支自动构建功能

为 `.github/workflows/build-apk.yml` 添加了对 `dev` 分支的支持。

#### 主要改动

1. **触发条件扩展**
   ```yaml
   on:
     push:
       branches:
         - main
         - dev  # 新增
   ```

2. **自动构建逻辑**
   - dev 分支推送时自动构建 debug APK，无需任何标签
   - main 分支保持原有行为（需要 commit message 标签）

3. **构建摘要增强**
   - 添加分支名称显示
   - 更清晰地展示构建来源

## 使用说明

### Dev 分支（自动构建）

```bash
# 推送到 dev 分支即可自动触发 debug 构建
git push origin dev
```

**特点：**
- ✅ 无需在 commit message 中添加任何标签
- ✅ 始终构建 debug 版本
- ✅ 适合开发迭代

### Main 分支（需要标签）

```bash
# Debug 构建
git commit -m "[build-apk] 描述信息"
git push origin main

# Release 构建
git commit -m "[build-apk:release] 版本发布"
git push origin main
```

## 构建矩阵

| 分支 | 触发方式 | 构建类型 | 说明 |
|------|---------|---------|------|
| dev | 自动 | Debug | 任何推送都会触发 |
| main | 手动（标签） | Debug | 需要 `[build-apk]` 或 `[build-apk:debug]` |
| main | 手动（标签） | Release | 需要 `[build-apk:release]` |

## 文件修改清单

- ✅ `.github/workflows/build-apk.yml` - 主 workflow 文件
- ✅ `.github/workflows/README_build-apk.md` - 详细使用文档（新增）

## 向后兼容性

- ✅ 完全向后兼容
- ✅ main 分支的现有行为保持不变
- ✅ 只是新增了 dev 分支的自动构建功能

## 使用场景

### 开发流程示例

```bash
# 1. 在 dev 分支开发
git checkout dev
git add .
git commit -m "实现新功能"
git push origin dev
# ✅ 自动构建 debug APK

# 2. 测试通过后合并到 main
git checkout main
git merge dev
git push origin main
# ❌ 不会构建（没有标签）

# 3. 需要构建测试版本
git commit --allow-empty -m "[build-apk] 测试构建"
git push origin main
# ✅ 构建 debug APK

# 4. 正式发布
git commit --allow-empty -m "[build-apk:release] 发布 v1.0.0"
git push origin main
# ✅ 构建 release APK
```

## 注意事项

1. **Dev 分支构建频率**
   - 每次推送都会触发构建，请确保代码可编译
   - 建议在本地测试通过后再推送

2. **APK 保存期限**
   - 所有构建的 APK 保留 30 天
   - 请及时下载重要版本

3. **忽略文件**
   - Markdown 文件变更不触发构建
   - 纯文档更新不会浪费构建资源

## 详细文档

完整使用说明请参考：[.github/workflows/README_build-apk.md](.github/workflows/README_build-apk.md)
