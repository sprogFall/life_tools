# 客户端页面性能缺陷清单

更新时间：2026-02-25

## 总览范围
- 客户端页面与关键组件：`lib/pages`、`lib/tools/**/pages`、`lib/tools/**/widgets`
- 本次优先处理可量化、可测试、可回归验证的问题

## 缺陷列表

### P1: `OvercookedImageByKey` 在重建时重复解析 URI（重复 I/O）
- 位置：`lib/tools/overcooked_kitchen/widgets/overcooked_image.dart`
- 现象：`_buildNetworkFallback` 在 `build` 中直接创建 `resolveUri` 的 `Future`，组件重建时会重复触发 URI 解析。
- 影响：列表/卡片频繁重建时引发不必要的异步调用，增加 CPU 与 I/O 开销，可能导致抖动。
- 修复：
  - 将 URI 解析 `Future` 缓存到状态字段；
  - 仅在 key 或 service 变化时失效并重建。
- 验证：
  - `test/tools/overcooked_kitchen/overcooked_image_performance_test.dart`
  - 用例：`OvercookedImageByKey 重建时不应重复解析 URI`

### P2: `OvercookedImageViewerPage` 子组件重复触发缓存与 URI 查询
- 位置：`lib/tools/overcooked_kitchen/pages/recipe/overcooked_image_viewer_page.dart`
- 现象：`_DiskPreferredImageView` / `_NetworkImageView` 原为 `StatelessWidget`，`FutureBuilder` 的 `future` 在 `build` 中重复创建。
- 影响：页面状态更新（如父级重建、标题变化）会重复触发 `ensureCachedFile/resolveUri`，增加磁盘与网络开销。
- 修复：
  - 两个组件改为 `StatefulWidget`；
  - 在 `initState/didUpdateWidget` 管理并复用 `Future`，避免无效重复请求。
- 验证：
  - `test/tools/overcooked_kitchen/overcooked_image_performance_test.dart`
  - 用例：`OvercookedImageViewerPage 重建时不应重复触发缓存/URI 查询`

### P3: `OvercookedWishlistTab` 标签加载串行，刷新链路偏长
- 位置：`lib/tools/overcooked_kitchen/pages/tabs/overcooked_wishlist_tab.dart`
- 现象：`ingredient` 与 `sauce` 标签查询独立却串行执行。
- 影响：愿望单页面首屏/切日刷新等待时长增加。
- 修复：
  - 将两类标签查询改为 `Future.wait` 并行。
- 验证：
  - `test/tools/overcooked_kitchen/overcooked_async_load_parallel_test.dart`
  - 用例：`愿望单刷新应并行触发食材/调味标签查询`

### P4: `OvercookedRecipeDetailPage` 四类标签查询串行
- 位置：`lib/tools/overcooked_kitchen/pages/recipe/overcooked_recipe_detail_page.dart`
- 现象：菜谱详情加载时，四类标签依次查询。
- 影响：详情页打开耗时随标签查询次数线性叠加。
- 修复：
  - 菜谱读取与四类标签读取统一并行发起，统一等待结果。
- 验证：
  - `test/tools/overcooked_kitchen/overcooked_async_load_parallel_test.dart`
  - 用例：`菜谱详情加载应并行触发四类标签查询`

### P5: `OvercookedRecipeEditPage` 四类标签查询串行
- 位置：`lib/tools/overcooked_kitchen/pages/recipe/overcooked_recipe_edit_page.dart`
- 现象：编辑页初始化标签数据为串行查询。
- 影响：进入编辑页等待时间增加。
- 修复：
  - 四类标签改为 `Future.wait` 并行加载。
- 验证：
  - `test/tools/overcooked_kitchen/overcooked_async_load_parallel_test.dart`
  - 用例：`菜谱编辑页加载应并行触发四类标签查询`

### P6: `OvercookedMealTab` 每餐评分查询串行
- 位置：`lib/tools/overcooked_kitchen/pages/tabs/overcooked_meal_tab.dart`
- 现象：多餐次评分逐个 `await` 查询。
- 影响：当餐次数增加时，刷新耗时近似线性增长。
- 修复：
  - 多餐次评分查询改为并行批量等待，并按原餐次回填。
- 验证：
  - `test/tools/overcooked_kitchen/overcooked_async_load_parallel_test.dart`
  - 用例：`三餐页刷新应并行触发每个餐次评分查询`

### P7: `WorkLogService` 任务扩展信息加载串行
- 位置：`lib/tools/work_log/services/work_log_service.dart`
- 现象：
  - 任务总耗时按任务逐条串行加载；
  - 任务总耗时与标签映射也串行执行。
- 影响：任务列表首轮加载和分页加载耗时变长。
- 修复：
  - 任务总耗时改为并行请求；
  - 总耗时与标签映射改为并行等待。
- 验证：
  - `test/tools/work_log/work_log_parallel_load_test.dart`
  - 用例：`WorkLogService.loadTasks 应并行触发任务耗时查询`

### P8: `WorkLogSyncProvider.exportData` 工时导出串行
- 位置：`lib/tools/work_log/sync/work_log_sync_provider.dart`
- 现象：按任务逐条查询工时记录，导出链路串行。
- 影响：任务数较多时导出耗时显著增加。
- 修复：
  - 任务工时导出改为并行查询后统一汇总。
- 验证：
  - `test/tools/work_log/work_log_parallel_load_test.dart`
  - 用例：`WorkLogSyncProvider.exportData 应并行触发多任务工时导出`

## 已执行回归
- `flutter test test/tools/overcooked_kitchen/overcooked_image_performance_test.dart`
- `flutter test test/tools/overcooked_kitchen/overcooked_async_load_parallel_test.dart`
- `flutter test test/tools/work_log/work_log_parallel_load_test.dart`
- `LD_LIBRARY_PATH=/tmp flutter test test/tools/overcooked_kitchen/overcooked_recipe_detail_page_widget_test.dart`
- `LD_LIBRARY_PATH=/tmp flutter test test/tools/overcooked_kitchen/overcooked_gacha_tab_widget_test.dart`
