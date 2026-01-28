import '../../tools/overcooked_kitchen/overcooked_constants.dart';
import '../../tools/stockpile_assistant/stockpile_constants.dart';
import '../../tools/work_log/work_log_constants.dart';
import 'models/tag_category.dart';
import 'tag_service.dart';

/// 应用内置的「工具-标签分类」注册入口。
///
/// 目标：
/// - 以硬编码形式在应用启动时注册，避免依赖“进入工具页才注册”；
/// - 仅注册分类（不预置标签数据），标签由用户在「标签管理」中维护。
class BuiltInTagCategories {
  BuiltInTagCategories._();

  static void registerAll(TagService tagService) {
    // 工作记录：把“标签”语义明确为“归属”（项目/客户/团队/OKR…）
    tagService.registerToolTagCategories(WorkLogConstants.toolId, const [
      TagCategory(
        id: WorkLogTagCategories.affiliation,
        name: '归属',
        createHint: '项目A/客户B/团队C/OKR',
      ),
    ]);

    // 囤货助手：物品类型 + 位置
    tagService.registerToolTagCategories(StockpileConstants.toolId, const [
      TagCategory(
        id: StockpileTagCategories.itemType,
        name: '物品类型',
        createHint: '零食/调料/日化/母婴',
      ),
      TagCategory(
        id: StockpileTagCategories.location,
        name: '位置',
        createHint: '冰箱/冷冻/橱柜/阳台',
      ),
    ]);

    // 胡闹厨房：菜谱/扭蛋机需要分类筛选
    tagService.registerToolTagCategories(OvercookedConstants.toolId, const [
      TagCategory(
        id: OvercookedTagCategories.dishType,
        name: '菜品风格',
        createHint: '下饭/快手/宴客/减脂',
      ),
      TagCategory(
        id: OvercookedTagCategories.ingredient,
        name: '主料',
        createHint: '鸡腿肉/虾仁/土豆',
      ),
      TagCategory(
        id: OvercookedTagCategories.sauce,
        name: '调味',
        createHint: '生抽/老抽/蚝油',
      ),
      TagCategory(
        id: OvercookedTagCategories.flavor,
        name: '风味',
        createHint: '酸/甜/辣/咸',
      ),
      TagCategory(
        id: OvercookedTagCategories.mealSlot,
        name: '餐次',
        createHint: '早餐/午餐/晚餐/加餐/中班午餐',
      ),
    ]);
  }
}
