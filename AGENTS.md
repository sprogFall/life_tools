# Repository Guidelines

## Agent 注意事项
1. 永远用中文回答。

## 开发原则
1. TDD：先写/补测试，再写功能；改动后必须完成对应校验。
2. 简约：避免过度设计。
3. 去重：避免重复逻辑，优先复用。

## 规范入口（按需查阅）
- 代码规范：`examples/code_standards.md`
- UI 规范：`examples/ui.md`
- AI/对象存储/标签/消息：`examples/ai.md`、`examples/objStore.md`、`examples/tags.md`、`examples/message.md`

## 提交与发布流程（三段式）
按顺序执行以下脚本：

1. `bash scripts/pre-push.sh`
- 自动识别改动范围并执行对应校验：
- Flutter 改动：`flutter pub get`、`flutter analyze`、`flutter test`
- 仅后端改动：执行后端测试（默认 `backend/sync_server`）
- 仅文档改动：跳过测试

2. `bash scripts/exec-push.sh --stage-all --push --summary "你的改动摘要"`
- 汇总改动、生成规范化 commit message、执行 commit 与 push。

3. `bash scripts/post-push.sh`
- 轮询 GitHub Action 状态并输出 run URL/最终结论。
- 常用参数：`--force-monitor`、`--max-polls`。

## 兼容补充规则（对齐原版）
1. 校验分流与原版一致：
- 涉及 Flutter 侧改动时，必须通过 `flutter analyze` 与 `flutter test`（由 `pre-push.sh` 执行）。
- 仅后端改动时，不跑 Flutter 校验，只跑后端测试。
- 仅文档改动时，可不执行 Flutter/后端测试。
2. 提交信息以 `doc:` / `docs:` 开头时，远端构建默认跳过（除非显式强制监控）。
3. `post-push.sh` 默认会对“仅 backend/docs 或 doc 前缀提交”跳过轮询；需要时用 `--force-monitor` 覆盖。
4. Linux 下若 `flutter test` 报 `libsqlite3.so` 缺失，可先执行：
- `ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /tmp/libsqlite3.so`
- `LD_LIBRARY_PATH=/tmp flutter test`
5. 任务若明确要求“排除国际化内容”，不主动改动 i18n 文案语义与键值。

## Git 提交规范
1. 推荐格式：`type(scope): 简要说明`
2. `type` 建议：`feat`、`fix`、`refactor`、`chore`、`docs`、`test`、`style`、`ci`、`revert`
3. 文档提交建议用 `doc:` / `docs:` 前缀。
4. 禁止模糊标题：`update`、`misc`、`wip`、`临时改动`。

## 安全与隐私红线
1. 禁止在日志/异常中输出密钥与 Token。
2. 本地路径拼接必须防止 `../` 穿越（确保最终路径在 `baseDir` 内）。
3. 外部服务默认 `https`；如使用 `http` 必须明确提示风险。

## Windows 兼容
1. 推荐在 Git Bash 或 WSL 执行 `*.sh`。
2. PowerShell 可直接调用：`bash scripts/pre-push.sh` 等。
3. 若 `bash` 不在 PATH，可用：`"C:\Program Files\Git\bin\bash.exe" scripts/pre-push.sh`。

## 格式检查
1. 先检查：`dart format --output=none --set-exit-if-changed .`
2. 再修复：`dart format .`
