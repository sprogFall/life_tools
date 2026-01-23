import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/messages/message_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../overcooked_constants.dart';
import '../repository/overcooked_repository.dart';
import '../services/overcooked_image_cache_service.dart';
import '../services/overcooked_reminder_service.dart';
import 'tabs/overcooked_calendar_tab.dart';
import 'tabs/overcooked_gacha_tab.dart';
import 'tabs/overcooked_meal_tab.dart';
import 'tabs/overcooked_recipes_tab.dart';
import 'tabs/overcooked_wishlist_tab.dart';

class OvercookedToolPage extends StatefulWidget {
  final OvercookedRepository? repository;

  const OvercookedToolPage({super.key, this.repository});

  @override
  State<OvercookedToolPage> createState() => _OvercookedToolPageState();
}

class _OvercookedToolPageState extends State<OvercookedToolPage> {
  late final OvercookedRepository _repository;
  int _tab = 0;

  DateTime _wishDate = DateTime.now();
  DateTime _mealDate = DateTime.now();
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _calendarRefreshToken = 0;
  DateTime _gachaTargetDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? OvercookedRepository();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refreshTodayReminderIfNeeded(DateTime date) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d != today) return;
    final messageService = context.read<MessageService>();
    await OvercookedReminderService(
      repository: _repository,
    ).pushDueReminders(messageService: messageService, now: now);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<OvercookedRepository>.value(value: _repository),
        Provider<OvercookedImageCacheService>(
          create: (_) => OvercookedImageCacheService(
            baseDirProvider: _defaultOvercookedImageCacheBaseDir,
          ),
        ),
      ],
      child: Scaffold(
        backgroundColor: IOS26Theme.backgroundColor,
        body: Stack(
          children: [
            Positioned(
              top: -90,
              right: -90,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      IOS26Theme.toolOrange.withValues(alpha: 0.18),
                      IOS26Theme.toolOrange.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -70,
              left: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      IOS26Theme.toolPink.withValues(alpha: 0.12),
                      IOS26Theme.toolPink.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(context),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: IOS26Theme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  OvercookedConstants.toolName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: IOS26Theme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _tab,
      children: [
        OvercookedRecipesTab(onJumpToGacha: () => setState(() => _tab = 4)),
        OvercookedWishlistTab(
          date: _wishDate,
          onDateChanged: (d) => setState(() => _wishDate = d),
          onWishesChanged: () => _refreshTodayReminderIfNeeded(_wishDate),
        ),
        OvercookedMealTab(
          date: _mealDate,
          onDateChanged: (d) => setState(() => _mealDate = d),
          onMealsChanged: () => setState(() => _calendarRefreshToken++),
        ),
        OvercookedCalendarTab(
          month: _calendarMonth,
          refreshToken: _calendarRefreshToken,
          onMonthChanged: (m) => setState(() => _calendarMonth = m),
          onOpenDay: (d) {
            setState(() {
              _mealDate = d;
              _tab = 2;
            });
          },
        ),
        OvercookedGachaTab(
          targetDate: _gachaTargetDate,
          onTargetDateChanged: (d) => setState(() => _gachaTargetDate = d),
          onImportToWish: (date) async {
            if (!mounted) return;
            await _refreshTodayReminderIfNeeded(date);
          },
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _tab,
      onTap: (i) => setState(() => _tab = i),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: IOS26Theme.primaryColor,
      unselectedItemColor: IOS26Theme.textSecondary,
      backgroundColor: IOS26Theme.surfaceColor,
      items: const [
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.book), label: '菜谱'),
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.heart), label: '愿望单'),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.square_list),
          label: '记录',
        ),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.calendar),
          label: '日历',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.casino_rounded), label: '扭蛋'),
      ],
    );
  }
}

Future<Directory> _defaultOvercookedImageCacheBaseDir() async {
  final base = await getTemporaryDirectory();
  final dir = Directory(p.join(base.path, 'life_tools_cache'));
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir;
}
