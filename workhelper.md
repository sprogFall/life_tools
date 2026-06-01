# 外拍记录工具可行性与技术方案

## 1. 结论

该需求在当前项目架构下可行，建议新增一个独立工具，暂定名为「外拍记录」，工具 ID 建议使用 `work_photo`。

实现方案明确采用完整的应用内相机方案：新增 `camera` 依赖，由 App 自己控制相机预览、拍摄项栏、快门、闪光灯、连续拍摄和拍后回显。不使用系统相机页作为主方案。

首版建议采用“本地优先 + 自定义配置驱动”方案：

- 用户先配置任意多层级分类，例如 2 层、3 层、4 层都可以，层级名称由用户自定义，不在代码里写死业务字段。
- 用户配置拍摄项，例如“桌子、门头、人物”等，也可以改成任何名称。
- 创建项目时选择一组层级值，并加载当前启用的拍摄项。
- 进入拍摄页后一次性加载所有配置的拍摄项，用户可以逐一快速拍，也可以只拍其中一部分后退出，后续继续拍。
- 拍照后立即无感保存：图片写入本地文件，关联关系写入 SQLite，不需要手动点击保存。
- 导出时选择一个或多个项目，按用户配置的层级和拍摄项生成多级文件夹 ZIP，通过 `file_saver` 保存到本地，必要时复用现有 `ShareService` 分享。

## 2. 当前项目现状

当前项目是 Flutter 应用，主要模式如下：

- 工具入口：`lib/core/registry/tool_registry.dart` 统一注册工具，首页和工具管理依赖 `ToolInfo`。
- 状态管理：使用 `provider`，全局服务在 `lib/main.dart` 的 `MultiProvider` 注册。
- 本地数据：使用 `sqflite`，数据库入口是 `lib/core/database/database_helper.dart`，表结构和迁移集中在 `lib/core/database/database_schema.dart`，当前版本是 `19`。
- UI 规范：iOS 26 风格组件和主题在 `lib/core/theme/ios26_theme.dart`、`lib/core/ui`、`lib/core/widgets`，业务页面应复用 `IOS26AppBar`、`IOS26Button`、`IOS26Icon`、`IOS26Image` 等组件。
- 图片能力：已有 `image_picker`、`flutter_image_compress`、`path_provider`，并有对象存储模块 `ObjStoreService`。本工具拍摄主流程新增 `camera`；已有 `image_picker` 仅作为其他模块能力，不作为本工具主拍摄方案。
- 导出能力：已有 `file_saver` 用于保存文件，`share_plus` 通过 `ShareService` 用于分享导出文件。
- 备份/同步：同步/备份通过 `ToolSyncProvider` 暴露 JSON 快照，适合元数据，不适合直接塞入大量图片二进制。

平台权限现状：

- Android Manifest 目前有录音、网络、定位、通知等权限，尚未声明相机权限。
- iOS `Info.plist` 目前有麦克风、语音识别、相册权限，尚未声明 `NSCameraUsageDescription`。

新增外拍记录工具需要补齐相机权限配置，并在页面层处理权限未授权、相机初始化失败、设备无可用摄像头等状态。

## 3. 需求拆解

用户核心流程可以拆成四块：

1. 预配置
   - 自定义层级结构：层级数量、层级名称、层级顺序都由用户配置。
   - 自定义层级选项：每层有哪些选项，可支持父子级联，也可首版只做逐层选择。
   - 自定义拍摄项：配置需要拍摄的项、顺序、最少张数、最多张数。
   - 自定义导出规则：导出目录可由项目名、层级值、拍摄项、拍摄日期等变量组成。

2. 外拍项目
   - 创建项目，填写项目名，可选择一组层级值，可填写备注。
   - 创建项目时保存层级名称、层级值、拍摄项名称的快照，避免后续修改配置影响历史项目。
   - 项目可以未完成保存，后续继续补拍。

3. 拍摄
   - 进入项目后打开应用内相机页。
   - 页面初始化时加载当前项目的全部拍摄项。
   - 相机预览下方展示所有拍摄项框，每个框显示名称、已拍张数、完成状态。
   - 点某个拍摄项后，它成为当前拍摄目标；按快门即保存到该项。
   - 拍完立即写入本地图片文件和数据库关联，不需要手动保存。
   - 支持连续拍、快速切换拍摄项、退出后继续拍、重拍、删除、查看最近一张。

4. 导出
   - 选择一个或多个项目。
   - 按配置的层级和拍摄项生成多级文件夹。
   - 把图片打包成 ZIP。
   - 保存到本地，必要时分享。

## 4. 技术选型

### 4.1 相机

唯一主方案：新增 `camera` 依赖，实现应用内相机预览和拍摄控制。

理由：

- 用户要求的交互是“打开功能后在相机预览里直接按拍摄项快速采集”，需要 App 自己控制预览和底部拍摄项栏。
- `camera` 支持持续预览、拍照、切换摄像头、闪光灯、连续采集和自定义 UI。
- 拍照后可以不离开页面，立即进入下一张或切换拍摄项，符合外出现场快速采集场景。
- 当前已有 `permission_handler`，可复用做权限前置检查和错误提示。

实现细节建议：

- `WorkPhotoCameraController` 或 `WorkPhotoCameraService` 负责初始化摄像头、释放资源、拍照、闪光灯、切换镜头。
- 页面进入时加载项目和全部拍摄项，再初始化相机。
- 拍照按钮防连点：拍摄中禁用快门，完成后立即恢复。
- 拍照成功后先拿到临时文件，再交给 `WorkPhotoMediaStore` 落盘，最后写入数据库。
- 如果数据库写入失败，应删除刚写入的图片文件，避免孤儿文件。
- 如果文件写入失败，不创建数据库记录。

### 4.2 图片存储

推荐新增工具内本地媒体服务：`WorkPhotoMediaStore`。

保存位置建议：

```text
Documents/life_tools_work_photo/
  photos/
    <projectId>/
      <assetId>.jpg
  export_cache/
```

设计要点：

- 数据库只存相对路径或内部 key，不存图片二进制。
- 文件名由系统生成，避免用户输入直接进入真实路径。
- 所有导出目录名都经过安全清理，去掉 `/`、`\`、`..`、控制字符和系统保留字符。
- 保存图片时可复用 `flutter_image_compress` 控制尺寸和质量，默认保留足够清晰度。
- 不建议首版强依赖 `ObjStoreService`，因为该服务依赖对象存储配置；外拍记录应在零配置下离线可用。后续如果要跨设备同步图片，再把对象存储作为增强能力。

### 4.3 ZIP 导出

推荐新增 `archive` 依赖生成 ZIP，复用已有 `file_saver` 保存 ZIP 文件。

导出策略：

- 小批量导出：内存生成 ZIP bytes 后调用 `FileSaver.instance.saveFile`。
- 大批量导出：先写入临时目录，再保存或分享，避免内存峰值过高。
- ZIP 内部路径由配置模板生成，默认模板建议：

```text
<项目名>/
  <层级1值>/
    <层级2值>/
      <层级N值>/
        <拍摄项名>/
          <拍摄时间>_<拍摄项名>_<序号>.jpg
```

示例：

```text
外拍导出_20260601.zip
  2026-06-01_项目A/
    层级值A/
      层级值B/
        桌子/
          20260601_143011_桌子_001.jpg
        门头/
          20260601_143230_门头_001.jpg
        人物/
          20260601_143455_人物_001.jpg
```

### 4.4 本地数据库

建议在 `DatabaseSchema.version` 从 `19` 升到 `20`，新增外拍记录相关表。表结构必须支持自定义多层级，而不是固定业务字段。

首版表设计如下：

```sql
work_photo_hierarchy_levels (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  sort_index INTEGER NOT NULL DEFAULT 0,
  is_required INTEGER NOT NULL DEFAULT 1,
  is_archived INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)

work_photo_hierarchy_options (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  level_id INTEGER NOT NULL,
  parent_option_id INTEGER,
  name TEXT NOT NULL,
  sort_index INTEGER NOT NULL DEFAULT 0,
  is_archived INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (level_id) REFERENCES work_photo_hierarchy_levels(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_option_id) REFERENCES work_photo_hierarchy_options(id) ON DELETE CASCADE
)

work_photo_capture_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  sort_index INTEGER NOT NULL DEFAULT 0,
  min_count INTEGER NOT NULL DEFAULT 1,
  max_count INTEGER,
  is_archived INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)

work_photo_export_profiles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  folder_template TEXT NOT NULL DEFAULT '',
  file_template TEXT NOT NULL DEFAULT '',
  is_default INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)

work_photo_projects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  status INTEGER NOT NULL DEFAULT 0,
  note TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)

work_photo_project_hierarchy_values (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL,
  level_id INTEGER,
  option_id INTEGER,
  level_name_snapshot TEXT NOT NULL,
  option_name_snapshot TEXT NOT NULL,
  sort_index INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (project_id) REFERENCES work_photo_projects(id) ON DELETE CASCADE,
  FOREIGN KEY (level_id) REFERENCES work_photo_hierarchy_levels(id) ON DELETE SET NULL,
  FOREIGN KEY (option_id) REFERENCES work_photo_hierarchy_options(id) ON DELETE SET NULL
)

work_photo_project_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL,
  source_item_id INTEGER,
  name_snapshot TEXT NOT NULL,
  sort_index INTEGER NOT NULL DEFAULT 0,
  min_count INTEGER NOT NULL DEFAULT 1,
  max_count INTEGER,
  FOREIGN KEY (project_id) REFERENCES work_photo_projects(id) ON DELETE CASCADE,
  FOREIGN KEY (source_item_id) REFERENCES work_photo_capture_items(id) ON DELETE SET NULL
)

work_photo_assets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL,
  project_item_id INTEGER NOT NULL,
  relative_path TEXT NOT NULL,
  original_filename TEXT NOT NULL DEFAULT '',
  mime_type TEXT NOT NULL DEFAULT 'image/jpeg',
  file_size INTEGER NOT NULL DEFAULT 0,
  width INTEGER,
  height INTEGER,
  taken_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (project_id) REFERENCES work_photo_projects(id) ON DELETE CASCADE,
  FOREIGN KEY (project_item_id) REFERENCES work_photo_project_items(id) ON DELETE CASCADE
)
```

建议索引：

- `idx_work_photo_hierarchy_levels_sort`
- `idx_work_photo_hierarchy_options_level_parent_sort`
- `idx_work_photo_capture_items_sort`
- `idx_work_photo_projects_updated_at`
- `idx_work_photo_project_hierarchy_values_project_id`
- `idx_work_photo_project_items_project_id`
- `idx_work_photo_assets_project_id`
- `idx_work_photo_assets_project_item_id`
- `idx_work_photo_assets_taken_at`

## 5. 模块设计

建议目录：

```text
lib/tools/work_photo/
  work_photo_constants.dart
  models/
    work_photo_hierarchy_level.dart
    work_photo_hierarchy_option.dart
    work_photo_capture_item.dart
    work_photo_export_profile.dart
    work_photo_project.dart
    work_photo_project_hierarchy_value.dart
    work_photo_project_item.dart
    work_photo_asset.dart
  repository/
    work_photo_repository.dart
  services/
    work_photo_media_store.dart
    work_photo_export_service.dart
    work_photo_camera_service.dart
  sync/
    work_photo_sync_provider.dart
  pages/
    work_photo_tool_page.dart
    work_photo_config_page.dart
    work_photo_project_edit_page.dart
    work_photo_project_detail_page.dart
    work_photo_camera_page.dart
    work_photo_export_page.dart
  widgets/
    work_photo_hierarchy_picker.dart
    work_photo_item_bar.dart
    work_photo_asset_grid.dart
```

核心职责：

- `WorkPhotoRepository`：层级配置、层级选项、拍摄项、项目、项目快照、图片记录的增删改查。
- `WorkPhotoMediaStore`：图片落盘、删除、解析文件、路径安全校验。
- `WorkPhotoCameraService`：相机初始化、释放、拍照、闪光灯、切换镜头。
- `WorkPhotoCameraPage`：应用内相机预览，底部拍摄项选择，拍照后自动调用媒体服务和仓库。
- `WorkPhotoExportService`：查询项目和图片，按模板生成导出路径，打包 ZIP。
- `WorkPhotoSyncProvider`：只导出/导入元数据；图片二进制不进入通用备份 JSON。

## 6. UI 流程

### 工具首页

- 顶部：项目列表、导出入口、配置入口。
- 列表项：项目名、自定义层级摘要、完成度，例如 `2/3 项已拍`。
- 操作：新建项目、继续拍摄、查看详情、导出。

### 配置页

- 层级维护：新增层级、重命名、调整顺序、归档。
- 层级选项维护：为每个层级维护选项；支持父子级联时，下层选项可挂到上层选项下。
- 拍摄项维护：新增“桌子、门头、人物”等，配置最少张数/最多张数，调整顺序。
- 导出规则：配置文件夹模板和文件名模板；首版可提供默认模板，后续开放更多变量。

### 项目详情页

- 展示项目基本信息、自定义层级摘要和各拍摄项完成情况。
- 每个拍摄项展示缩略图、张数、缺失状态。
- 支持进入拍摄页、删除照片、补拍、项目导出。

### 拍摄页

推荐布局：

- 主体：应用内相机预览，尽量全屏。
- 底部：稳定高度的拍摄项栏，加载当前项目全部拍摄项，每个框显示名称、已拍张数、是否达标。
- 主按钮：快门。
- 辅助按钮：切换摄像头、闪光灯、退出、查看最近一张。

交互建议：

- 页面进入后自动选择第一个未达标拍摄项。
- 点某个拍摄项后，它成为当前拍摄目标，按快门即保存到该项。
- 拍照成功后立即无感落盘并写入数据库，同时更新该拍摄项张数。
- 如果当前拍摄项达到最少张数，可自动跳到下一个未达标拍摄项；用户也可以手动切换。
- 如果所有拍摄项都达标，仍允许继续补拍，除非对应项配置了 `max_count`。
- 用户可以拍一部分后直接退出，项目保留当前进度，下次进入继续从未达标项开始。
- 拍照失败时只提示错误，不创建数据库记录。
- 文件写入成功但数据库写入失败时，应删除刚写入的文件，避免孤儿文件。

## 7. 导出规则

导出服务输入：

- 项目 ID 列表。
- 导出模板，首版可使用默认模板。
- 是否跳过缺失项，首版建议不阻塞导出，但在导出前提示缺失情况。

导出服务输出：

- ZIP 文件名，例如 `外拍导出_20260601_1430.zip`。
- ZIP bytes 或临时 ZIP 文件路径。

目录名清理规则：

- 去除路径分隔符 `/`、`\`。
- 去除 `..`。
- 去除 Windows 保留字符 `< > : " | ? *`。
- 空名称统一替换为 `未命名`。
- 同目录重名文件追加序号。

模板变量建议：

- `{projectName}`：项目名。
- `{levelPath}`：按层级顺序拼接的全部层级值。
- `{level:层级名}`：指定层级值。
- `{itemName}`：拍摄项名称。
- `{takenDate}`：拍摄日期。
- `{takenTime}`：拍摄时间。
- `{index}`：同一目录下的序号。

导出前校验：

- 项目存在。
- 图片记录对应文件存在。
- 缺失文件写入导出报告 `导出说明.txt`，不要静默跳过。

## 8. 同步与备份边界

首版建议：

- 新工具实现 `ToolSyncProvider`，用于导出层级配置、拍摄项配置、项目、项目快照、图片元数据。
- 不把图片二进制放进通用备份 JSON，避免备份体积巨大和恢复过程不稳定。
- 工具自己的“图片导出 ZIP”是独立能力，不等同于全量备份。

后续增强：

- 若用户需要跨设备保留图片，可接入 `ObjStoreService`，将图片上传到 local/qiniu/dataCapsule，并在 `work_photo_assets` 增加 `object_key`、`storage_type` 字段。
- 通用备份可继续只保存 metadata 和 object key，图片通过对象存储恢复。

## 9. 需要改动的文件

实施时预计涉及：

- `pubspec.yaml`
  - 新增 `camera`。
  - 新增 `archive`。
- `android/app/src/main/AndroidManifest.xml`
  - 增加相机权限。
- `ios/Runner/Info.plist`
  - 增加 `NSCameraUsageDescription`。
- `lib/core/database/database_schema.dart`
  - 版本升到 `20`，新增外拍记录相关表和升级迁移。
- `lib/core/registry/tool_registry.dart`
  - 注册 `work_photo` 工具和同步 provider。
- `lib/tools/work_photo/**`
  - 新增模型、仓库、服务、页面、组件、同步 provider。
- `lib/l10n/*.arb`
  - 新增 UI 文案并运行 `flutter gen-l10n`。
- `test/tools/work_photo/**`
  - 新增仓库、导出、路径清理、相机服务状态、页面基础测试。

## 10. 测试策略

按当前仓库原则，建议 TDD 实施：

1. Repository 测试
   - 新建层级、层级选项、拍摄项。
   - 新建项目时生成层级值快照和拍摄项快照。
   - 删除项目级联删除项目层级值、项目拍摄项和图片记录。

2. MediaStore 测试
   - 文件保存到指定目录。
   - 相对路径解析不能越过根目录。
   - 数据库失败时清理已写文件。

3. Camera 流程测试
   - 相机初始化失败时展示错误状态。
   - 拍照中禁用快门，避免重复触发。
   - 拍照成功后自动写入图片记录，无需手动保存。
   - 退出后再次进入能恢复拍摄进度。

4. ExportService 测试
   - 多项目导出目录结构正确。
   - 自定义多层级路径按层级顺序生成。
   - 名称清理正确处理 `/`、`..`、空名称和重名。
   - 缺失图片会写入导出说明。

5. Widget 测试
   - 工具首页展示项目完成度。
   - 配置页可维护层级和拍摄项。
   - 项目详情页显示缺失项和已拍缩略图。

6. 规范测试
   - 遵守现有 UI 规范，避免直接使用原生 `Image.file`，展示图片走 `IOS26Image`。
   - 新文案进入 ARB，不硬编码在 UI 中。

## 11. 推荐实施顺序

1. 新增数据模型、Repository 和数据库迁移。
2. 补 Repository 单元测试。
3. 新增 `WorkPhotoMediaStore` 和路径安全测试。
4. 新增 `WorkPhotoExportService`，接入 ZIP 生成和保存，补导出测试。
5. 注册工具入口，完成配置页、项目页、详情页。
6. 引入 `camera`，完成 `WorkPhotoCameraService` 和应用内相机页。
7. 接入无感保存流程：拍照成功后自动落盘、写库、更新拍摄项状态。
8. 接入 `ToolSyncProvider` 元数据备份。
9. 执行 `bash scripts/pre-push.sh` 做最终校验。

## 12. 风险与取舍

- 应用内相机页比系统相机页成本更高，但这是满足连续拍摄、拍摄项栏、无感保存的必要实现。
- ZIP 大文件可能造成内存压力，应限制单次导出项目数或改为临时文件流式生成。
- 图片体积会快速增长，需要在项目详情或设置里提供“删除项目时删除图片文件”的能力。
- 修改配置后不能影响历史项目，因此项目必须保存层级名称、层级值、拍摄项名称快照。
- 通用同步不适合直接传图片，首版应明确“导出 ZIP 发送电脑”是图片转移主路径。

## 13. 首版验收标准

- 可以配置任意数量的自定义层级。
- 可以配置层级选项和拍摄项。
- 可以创建外拍项目，并根据当前配置生成层级值快照和拍摄项快照。
- 打开拍摄页后可以看到应用内相机预览和所有拍摄项。
- 可以逐一快速拍摄，也可以只拍一部分后退出，后续继续拍。
- 拍照后图片文件和关联关系自动本地持久化，不需要手动保存。
- 退出 App 后重新进入，项目进度和图片仍可查看。
- 可以选择一个或多个项目导出 ZIP。
- ZIP 内图片按项目、自定义层级、拍摄项分文件夹。
- 导出文件可保存到本地并分享。
- 相关 Repository、相机流程、导出服务、路径安全逻辑有测试覆盖。
