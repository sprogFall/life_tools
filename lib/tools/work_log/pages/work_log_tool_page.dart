import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/tags/tag_repository.dart';
import '../../../core/theme/ios26_theme.dart';
import '../../../core/widgets/ios26_floating_icon_button.dart';
import '../../../core/widgets/ios26_home_leading_button.dart';
import '../../../pages/home_page.dart';
import '../ai/work_log_ai_assistant.dart';
import '../ai/work_log_ai_intent.dart';
import '../models/work_log_drafts.dart';
import '../models/work_task.dart';
import '../repository/work_log_repository.dart';
import '../repository/work_log_repository_base.dart';
import '../services/work_log_service.dart';
import 'calendar/work_log_ai_summary_page.dart';
import 'calendar/work_log_calendar_view.dart';
import 'log/operation_log_list_page.dart';
import 'task/work_log_voice_input_sheet.dart';
import 'task/work_task_edit_page.dart';
import 'task/work_task_list_view.dart';
import 'task/work_task_sort_page.dart';
import 'time/work_time_entry_edit_page.dart';

class WorkLogToolPage extends StatefulWidget {
  final WorkLogRepositoryBase? repository;
  final WorkLogAiAssistant? aiAssistant;
  final TagRepository? tagRepository;

  const WorkLogToolPage({
    super.key,
    this.repository,
    this.aiAssistant,
    this.tagRepository,
  });

  @override
  State<WorkLogToolPage> createState() => _WorkLogToolPageState();
}

class _WorkLogToolPageState extends State<WorkLogToolPage> {
  int _tab = 0;
  late final WorkLogService _service;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _service = WorkLogService(
      repository: widget.repository ?? WorkLogRepository(),
      tagRepository:
          widget.tagRepository ??
          (widget.repository == null ? TagRepository() : null),
    );
    _service.loadTasks();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider.value(
      value: _service,
      child: Scaffold(
        backgroundColor: IOS26Theme.backgroundColor,
        body: BackdropGroup(
          child: Stack(
            children: [
              Positioned(
                top: -80,
                left: -80,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        IOS26Theme.toolBlue.withValues(alpha: 0.15),
                        IOS26Theme.toolBlue.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                right: -100,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        IOS26Theme.toolPurple.withValues(alpha: 0.12),
                        IOS26Theme.toolPurple.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    IOS26AppBar(
                      title: l10n.tool_work_log_name,
                      useSafeArea: false,
                      leading: IOS26HomeLeadingButton(
                        onPressed: () => _navigateToHome(context),
                      ),
                      actions: [
                        CupertinoButton(
                          padding: const EdgeInsets.all(IOS26Theme.spacingSm),
                          minimumSize: IOS26Theme.minimumTapSize,
                          onPressed: _openOperationLogs,
                          child: const Icon(
                            CupertinoIcons.time,
                            color: IOS26Theme.primaryColor,
                            size: 22,
                          ),
                        ),
                        if (_tab == 0)
                          Builder(
                            builder: (context) => CupertinoButton(
                              key: const ValueKey('work_log_sort_button'),
                              padding: const EdgeInsets.all(
                                IOS26Theme.spacingSm,
                              ),
                              minimumSize: IOS26Theme.minimumTapSize,
                              onPressed: () {
                                final service = context.read<WorkLogService>();
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (_) =>
                                        ChangeNotifierProvider.value(
                                          value: service,
                                          child: const WorkTaskSortPage(),
                                        ),
                                  ),
                                );
                              },
                              child: const Icon(
                                CupertinoIcons.arrow_up_arrow_down,
                                color: IOS26Theme.primaryColor,
                                size: 22,
                              ),
                            ),
                          ),
                        CupertinoButton(
                          padding: const EdgeInsets.all(IOS26Theme.spacingSm),
                          minimumSize: IOS26Theme.minimumTapSize,
                          onPressed: _onPressedAdd,
                          child: const Icon(
                            CupertinoIcons.add,
                            color: IOS26Theme.primaryColor,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    _buildPageIndicator(),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) => setState(() => _tab = index),
                        children: const [
                          WorkTaskListView(key: ValueKey('tasks')),
                          WorkLogCalendarView(key: ValueKey('calendar')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_tab == 0)
                IOS26FloatingIconButton(
                  buttonKey: const ValueKey('work_log_ai_input_button'),
                  icon: CupertinoIcons.sparkles,
                  semanticLabel: l10n.work_log_ai_entry,
                  onPressed: _openVoiceInput,
                ),
              if (_tab == 1)
                IOS26FloatingIconButton(
                  buttonKey: const ValueKey('work_log_ai_summary_button'),
                  icon: CupertinoIcons.sparkles,
                  semanticLabel: l10n.work_log_ai_summary_entry,
                  onPressed: _openAiSummary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IOS26Theme.spacingSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDot(0, l10n.common_tasks),
          const SizedBox(width: IOS26Theme.spacingXl + IOS26Theme.spacingXs),
          _buildDot(1, l10n.common_calendar),
        ],
      ),
    );
  }

  Widget _buildDot(int index, String label) {
    final isActive = _tab == index;
    return GestureDetector(
      onTap: () => _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? IOS26Theme.primaryColor
                  : IOS26Theme.textTertiary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: IOS26Theme.bodySmall.copyWith(
              color: isActive
                  ? IOS26Theme.primaryColor
                  : IOS26Theme.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  void _onPressedAdd() {
    Navigator.of(context)
        .push<bool>(
          CupertinoPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: _service,
              child: const WorkTaskEditPage(),
            ),
          ),
        )
        .then((saved) {
          if (saved == true && mounted) {
            _service.loadTasks();
          }
        });
  }

  void _openOperationLogs() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _service,
          child: const OperationLogListPage(),
        ),
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _openVoiceInput() async {
    final text = await WorkLogVoiceInputSheet.show(context);
    if (!mounted || text == null) return;

    final assistant = widget.aiAssistant ?? _maybeCreateAiAssistant(context);
    if (assistant == null) {
      await _showMessage('提示', '未找到 AI 服务，请确认已在应用入口注入 AiService。');
      return;
    }

    late final String jsonText;
    late final WorkLogAiIntent intent;
    try {
      _showLoading('AI 解析中…');
      jsonText = await assistant.voiceTextToIntentJson(
        voiceText: text,
        context: _buildAiContext(),
      );
      intent = WorkLogAiIntentParser.parse(jsonText);
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // loading
      await _showMessage('AI 调用失败', e.toString());
      return;
    }

    if (mounted) Navigator.of(context).pop(); // loading
    await _applyAiIntent(intent, rawJson: jsonText);
  }

  Future<void> _openAiSummary() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _service,
          child: const WorkLogAiSummaryPage(),
        ),
      ),
    );
  }

  WorkLogAiAssistant? _maybeCreateAiAssistant(BuildContext context) {
    try {
      final aiService = context.read<AiService>();
      return DefaultWorkLogAiAssistant(aiService: aiService);
    } on ProviderNotFoundException {
      return null;
    }
  }

  String _buildAiContext() {
    final now = DateTime.now();
    final tasks = _service.allTasks;
    final taskLines = tasks
        .where((t) => t.id != null)
        .take(60)
        .map((t) => '- [id=${t.id}] ${t.title}')
        .join('\n');

    return [
      '当前日期：${_formatDate(now)}',
      '现有任务列表（可能为空，供你在 task_ref 里选用 id/title）：',
      taskLines.isEmpty ? '- (无)' : taskLines,
    ].join('\n');
  }

  Future<void> _applyAiIntent(
    WorkLogAiIntent intent, {
    required String rawJson,
  }) async {
    if (intent is UnknownIntent) {
      await _showMessage('无法识别指令', '${intent.reason}\n\nAI 返回：\n$rawJson');
      return;
    }

    if (intent is CreateTaskIntent) {
      final saved = await Navigator.of(context).push<bool>(
        CupertinoPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: _service,
            child: WorkTaskEditPage(draft: intent.draft),
          ),
        ),
      );
      if (saved == true && mounted) {
        await _service.loadTasks();
      }
      return;
    }

    if (intent is AddTimeEntryIntent) {
      final taskId = await _resolveTaskIdForTimeEntry(ref: intent.taskRef);
      if (taskId == null || !mounted) return;

      // 获取任务标题
      final task = _service.allTasks.firstWhere(
        (t) => t.id == taskId,
        orElse: () => _service.allTasks.first,
      );

      final saved = await Navigator.of(context).push<bool>(
        CupertinoPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: _service,
            child: WorkTimeEntryEditPage(
              taskId: taskId,
              draft: intent.draft,
              taskTitle: task.title,
            ),
          ),
        ),
      );

      if (saved == true && mounted) {
        await _service.loadTasks();
      }
      return;
    }
  }

  Future<int?> _resolveTaskIdForTimeEntry({required WorkLogTaskRef ref}) async {
    final tasks = _service.allTasks.where((t) => t.id != null).toList();

    if (ref.id != null) {
      final exists = tasks.any((t) => t.id == ref.id);
      if (!exists) {
        await _showMessage('提示', '未找到 id=${ref.id} 对应的任务，请检查任务是否存在。');
        return null;
      }
      return ref.id;
    }

    final title = ref.title?.trim();
    if (title == null || title.isEmpty) {
      await _showMessage('提示', 'AI 未提供任务信息，请重试或手动选择任务后录入工时。');
      return null;
    }

    final lower = title.toLowerCase();
    final exact = tasks
        .where((t) => t.title.trim().toLowerCase() == lower)
        .toList();
    final candidates = exact.isNotEmpty
        ? exact
        : tasks.where((t) => t.title.toLowerCase().contains(lower)).toList();

    if (candidates.isEmpty) {
      final create = await _confirm(
        title: '未找到任务',
        content: '未找到「$title」，是否先创建该任务？',
        okText: '创建任务',
      );
      if (!create || !mounted) return null;

      final saved = await Navigator.of(context).push<bool>(
        CupertinoPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: _service,
            child: WorkTaskEditPage(draft: WorkTaskDraft(title: title)),
          ),
        ),
      );
      if (saved != true || !mounted) return null;

      await _service.loadTasks();
      final again = _service.tasks
          .where((t) => t.id != null && t.title.trim().toLowerCase() == lower)
          .toList();
      if (again.isEmpty) return null;
      return again.first.id;
    }

    if (candidates.length == 1) return candidates.first.id;

    return _pickTaskId(candidates);
  }

  Future<int?> _pickTaskId(List<WorkTask> candidates) async {
    return showCupertinoModalPopup<int?>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('选择任务'),
        message: const Text('AI 匹配到多个可能的任务，请选择一个'),
        actions: [
          for (final task in candidates)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, task.id),
              child: Text(task.title),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showLoading(String text) {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const CupertinoActivityIndicator(),
            const SizedBox(height: 12),
            Text(text),
          ],
        ),
      ),
    );
  }

  Future<void> _showMessage(String title, String content) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String content,
    String okText = '确定',
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(okText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static String _formatDate(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
