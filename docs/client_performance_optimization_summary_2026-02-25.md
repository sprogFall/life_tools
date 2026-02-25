# 客户端性能优化总结（2026-02-25）

## 本次目标
- 全量巡检客户端剩余代码中的性能热点。
- 将可优化点补充到 `docs/client_performance_issues.md`。
- 按清单完成可验证优化，并通过回归后推送远端。

## 重点优化项（已完成）
1. 图片组件重建重复 I/O
- `OvercookedImageByKey`：缓存 `resolveUri` 的 `Future`，避免重建重复解析。
- `OvercookedImageViewerPage`：图片子视图改为 `StatefulWidget`，缓存 `ensureCachedFile/resolveUri` 的 `Future`。

2. Overcooked 标签加载串行问题
- `OvercookedWishlistTab`：食材/调味标签查询改为并行。
- `OvercookedRecipeDetailPage`：菜谱与四类标签查询并行。
- `OvercookedRecipeEditPage`：四类标签查询并行。

3. Overcooked 三餐评分串行问题
- `OvercookedMealTab`：每餐评分查询由串行改为并行聚合。

4. WorkLog 串行加载问题
- `WorkLogService`：任务总耗时查询并行化；总耗时与标签映射并行等待。
- `WorkLogSyncProvider.exportData`：按任务导出工时由串行改为并行。

## 新增测试（TDD）
- `test/tools/overcooked_kitchen/overcooked_image_performance_test.dart`
- `test/tools/overcooked_kitchen/overcooked_async_load_parallel_test.dart`
- `test/tools/work_log/work_log_parallel_load_test.dart`

以上用例均先验证失败场景，再在优化后转绿。

## 关键改动文件
- `lib/tools/overcooked_kitchen/widgets/overcooked_image.dart`
- `lib/tools/overcooked_kitchen/pages/recipe/overcooked_image_viewer_page.dart`
- `lib/tools/overcooked_kitchen/pages/tabs/overcooked_wishlist_tab.dart`
- `lib/tools/overcooked_kitchen/pages/recipe/overcooked_recipe_detail_page.dart`
- `lib/tools/overcooked_kitchen/pages/recipe/overcooked_recipe_edit_page.dart`
- `lib/tools/overcooked_kitchen/pages/tabs/overcooked_meal_tab.dart`
- `lib/tools/work_log/services/work_log_service.dart`
- `lib/tools/work_log/sync/work_log_sync_provider.dart`
- `docs/client_performance_issues.md`

## 校验结果
1. 定向回归（全部通过）
- `flutter test test/tools/overcooked_kitchen/overcooked_image_performance_test.dart`
- `flutter test test/tools/overcooked_kitchen/overcooked_async_load_parallel_test.dart`
- `flutter test test/tools/work_log/work_log_parallel_load_test.dart`
- `LD_LIBRARY_PATH=/tmp flutter test`（多组 overcooked/work_log 相关回归）

2. 提交前脚本（全部通过）
- `bash scripts/pre-push.sh`
  - `flutter analyze`：通过
  - `flutter test`：通过（全量）

## 清单文档
- 性能缺陷清单已更新：`docs/client_performance_issues.md`
