import '../../tools/overcooked_kitchen/overcooked_constants.dart';
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
    // 胡闹厨房：菜谱/扭蛋机需要分类筛选
    tagService.registerToolTagCategories(OvercookedConstants.toolId, const [
      TagCategory(id: OvercookedTagCategories.dishType, name: '菜品风格'),
      TagCategory(id: OvercookedTagCategories.ingredient, name: '主料'),
      TagCategory(id: OvercookedTagCategories.sauce, name: '调味'),
      TagCategory(id: OvercookedTagCategories.flavor, name: '风味'),
    ]);
  }
}
