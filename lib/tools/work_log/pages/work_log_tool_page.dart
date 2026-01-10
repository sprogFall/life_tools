import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/ios26_theme.dart';
import '../../../pages/home_page.dart';
import '../repository/work_log_repository.dart';
import '../repository/work_log_repository_base.dart';
import '../services/work_log_service.dart';
import 'calendar/work_log_calendar_view.dart';
import 'task/work_task_edit_page.dart';
import 'task/work_task_list_view.dart';

class WorkLogToolPage extends StatefulWidget {
  final WorkLogRepositoryBase? repository;

  const WorkLogToolPage({super.key, this.repository});

  @override
  State<WorkLogToolPage> createState() => _WorkLogToolPageState();
}

class _WorkLogToolPageState extends State<WorkLogToolPage> {
  int _tab = 0;
  late final WorkLogService _service;

  @override
  void initState() {
    super.initState();
    _service = WorkLogService(
      repository: widget.repository ?? WorkLogRepository(),
    );
    _service.loadTasks();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _service,
      child: Scaffold(
        backgroundColor: IOS26Theme.backgroundColor,
        body: Stack(
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
                  _buildAppBar(context),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: _buildSegmentedControl(),
                  ),
                  Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _tab == 0
                            ? const WorkTaskListView(key: ValueKey('tasks'))
                            : const WorkLogCalendarView(
                                key: ValueKey('calendar'),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: IOS26Theme.glassColor,
            border: Border(
              bottom: BorderSide(
                color: IOS26Theme.textTertiary.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => _navigateToHome(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.home,
                      color: IOS26Theme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '首页',
                      style: TextStyle(
                        fontSize: 17,
                        color: IOS26Theme.primaryColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Text(
                  '工作记录',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.41,
                    color: IOS26Theme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: _onPressedAdd,
                child: const Icon(
                  CupertinoIcons.add,
                  color: IOS26Theme.primaryColor,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: IOS26Theme.glassColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: IOS26Theme.glassBorderColor,
          width: 1,
        ),
      ),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: _tab,
        thumbColor: IOS26Theme.surfaceColor,
        children: const {
          0: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text('任务'),
          ),
          1: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text('日历'),
          ),
        },
        onValueChanged: (value) {
          if (value == null) return;
          setState(() => _tab = value);
        },
      ),
    );
  }

  void _onPressedAdd() {
    if (_tab != 0) return;

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

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }
}
