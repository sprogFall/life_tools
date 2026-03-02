import '../../work_log/repository/work_log_repository_base.dart';
import 'xiao_mi_work_log_prompt_builder.dart';

class XiaoMiQuickPrompt {
  final String id;
  final String text;
  final String description;

  const XiaoMiQuickPrompt({
    required this.id,
    required this.text,
    required this.description,
  });
}

class XiaoMiResolvedPrompt {
  final String displayText;
  final String aiPrompt;
  final Map<String, dynamic>? metadata;

  const XiaoMiResolvedPrompt({
    required this.displayText,
    required this.aiPrompt,
    required this.metadata,
  });
}

class XiaoMiNoWorkLogDataException implements Exception {
  final String message;

  const XiaoMiNoWorkLogDataException([this.message = '未找到该时间范围内的工作记录']);

  @override
  String toString() => message;
}

class XiaoMiPromptResolver {
  final WorkLogRepositoryBase _workLogRepository;
  final DateTime Function() _nowProvider;

  const XiaoMiPromptResolver({
    required WorkLogRepositoryBase workLogRepository,
    DateTime Function()? nowProvider,
  }) : _workLogRepository = workLogRepository,
       _nowProvider = nowProvider ?? DateTime.now;

  static const XiaoMiQuickPrompt workLogYearSummary = XiaoMiQuickPrompt(
    id: 'work_log_year_summary',
    text: '今年工作总结',
    description: '隐式读取今年的工作记录，生成年度总结',
  );

  List<XiaoMiQuickPrompt> get quickPrompts => const [workLogYearSummary];

  Future<XiaoMiResolvedPrompt> resolveUserInput(String rawText) async {
    final text = rawText.trim();

    if (_isMatch(text, workLogYearSummary.text)) {
      final builder = XiaoMiWorkLogYearSummaryPromptBuilder(
        repository: _workLogRepository,
        nowProvider: _nowProvider,
      );
      final prompt = await builder.build();
      if (prompt == null) {
        throw const XiaoMiNoWorkLogDataException('今年没有可用的工作记录，无法生成总结');
      }
      return XiaoMiResolvedPrompt(
        displayText: text,
        aiPrompt: prompt,
        metadata: <String, dynamic>{'presetId': workLogYearSummary.id},
      );
    }

    return XiaoMiResolvedPrompt(
      displayText: text,
      aiPrompt: text,
      metadata: null,
    );
  }

  static bool _isMatch(String a, String b) {
    return a.trim() == b.trim();
  }
}
