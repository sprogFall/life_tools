# Life Tools 项目代码审查报告

**日期**: 2026-02-04
**审查范围**: `lib/` 及 `test/` (排除 `backend/`)

## 1. 概览
本次审查对 `lib` 目录下的前端及核心业务代码进行了系统性扫描。整体架构基于 Flutter，模块划分较为清晰，但在**国际化规范**、**异常处理严谨性**和**UI组件复用性**方面存在显著优化空间。

共识别出 3 大类主要问题，建议按优先级分阶段处理。

---

## 2. 问题详细清单

### 2.1 代码风格 (Style)

| 优先级 | 问题类型 | 描述 | 改进建议 |
| :--- | :--- | :--- | :--- |
| **High** | **硬编码字符串** | 全局约 87 个文件包含硬编码中文，阻碍国际化。 | 迁移至 `l10n/app_zh.arb`，使用 `AppLocalizations`。 |
| **Medium** | **超长组件** | 部分文件（如 `overcooked_recipe_edit_page.dart`）超过 900 行。 | 拆分 UI 组件，提取业务逻辑到 Service/ViewModel。 |
| **Medium** | **代码重复** | `overcooked` 与 `work_log` 存在相似 UI 逻辑。 | 提取通用 Widget 到 `lib/core/widgets`。 |

#### 典型案例
*   **硬编码字符串**:
    *   `lib/tools/work_log/pages/work_log_tool_page.dart`: `title: '工作记录'`
    *   `lib/tools/overcooked_kitchen/pages/recipe/overcooked_recipe_edit_page.dart`: `'暂无可用标签...'`
*   **复杂文件**:
    *   `lib/tools/overcooked_kitchen/pages/recipe/overcooked_recipe_edit_page.dart` (900+ 行): 混合了图片选择、文件 IO、表单校验和 UI 构建。
    *   `lib/core/tags/tag_repository.dart` (600+ 行): 包含复杂的标签查询逻辑，建议拆分查询对象。

---

### 2.2 结构设计 (Structure)

| 优先级 | 问题类型 | 描述 | 改进建议 |
| :--- | :--- | :--- | :--- |
| **Medium** | **逻辑耦合** | Page 层直接处理文件 IO 和数据转换。 | 引入 Service 层封装底层操作。 |
| **Medium** | **样式硬编码** | 大量使用 `EdgeInsets.all(8)` 和 `Colors.white`。 | 强制使用 `IOS26Theme` 常量。 |

#### 典型案例
*   **逻辑耦合**:
    *   `overcooked_recipe_edit_page.dart`: 直接调用 `ImagePicker` 并处理临时文件清理，应封装至 `ImagePickerService`。
*   **样式规范**:
    *   `work_log_tool_page.dart`: 使用了硬编码的 `padding` 值，未跟随设计规范。

---

### 2.3 业务逻辑 (Logic)

| 优先级 | 问题类型 | 描述 | 改进建议 |
| :--- | :--- | :--- | :--- |
| **High** | **异常吞噬** | 核心服务中存在空的 `catch (_) {}` 块。 | 必须添加 `logger.w/e` 记录，关键业务需 UI 反馈。 |
| **Medium** | **性能风险** | 滚动监听中频繁 `setState`。 | 使用 `ValueNotifier` 或节流 (Throttle)。 |
| **Low** | **技术债** | 少量 `TODO`/`FIXME` 标记。 | 制定清理计划。 |

#### 风险代码位置 (Empty Catch Blocks)
以下文件包含空的 `catch` 块，可能掩盖关键错误：
1.  `lib/core/obj_store/obj_store_service.dart`: 删除临时文件时。
2.  `lib/core/sync/services/backup_restore_service.dart`: 备份流程中。
3.  `lib/core/utils/no_media.dart`: 创建 `.nomedia` 文件时。
4.  `lib/core/obj_store/data_capsule/data_capsule_client.dart`

---

## 3. 优化行动计划

### 第一阶段：稳健性与规范（本周）
- [ ] **修复空 Catch**: 全局搜索 `catch (_) {}`，补充日志记录或错误提示。
- [ ] **统一主题常量**: 批量替换硬编码的 `Padding` 和 `Color` 为 `IOS26Theme` 引用。

### 第二阶段：架构重构（下周）
- [ ] **抽取通用组件**: 将 `overcooked` 和 `work_log` 中的重复 UI（如信息行、标签选择器）提取到 `lib/core/widgets`。
- [ ] **瘦身大文件**: 重构 `overcooked_recipe_edit_page.dart`，将图片处理逻辑移至 `Service`。

### 第三阶段：国际化迁移（长期）
- [ ] **提取字符串**: 逐步将 87 个文件中的中文字符串提取至 `arb` 文件，优先处理主页和核心工具页。
