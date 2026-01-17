import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/tags/models/tag.dart';
import '../../../core/theme/ios26_theme.dart';
import '../models/stock_item.dart';
import '../services/stockpile_service.dart';
import '../utils/stockpile_utils.dart';

class StockItemEditPage extends StatefulWidget {
  final int? itemId;

  const StockItemEditPage({super.key, this.itemId});

  @override
  State<StockItemEditPage> createState() => _StockItemEditPageState();
}

class _StockItemEditPageState extends State<StockItemEditPage> {
  late final StockpileService _service;

  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _unitController = TextEditingController();
  final _totalController = TextEditingController(text: '1');
  final _remainingController = TextEditingController(text: '1');
  final _remindDaysController = TextEditingController(text: '3');
  final _noteController = TextEditingController();

  DateTime _purchaseDate = DateTime.now();
  DateTime? _expiryDate;
  bool _hasExpiry = false;

  StockItem? _editing;
  Set<int> _selectedTagIds = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _service = context.read<StockpileService>();
    final id = widget.itemId;
    if (id != null) {
      _loading = true;
      Future<void>.microtask(() async {
        final item = await _service.getItem(id);
        final tagIds = await _service.listTagIdsForItem(id);
        if (!mounted) return;
        setState(() {
          _editing = item;
          _selectedTagIds = tagIds.toSet();
          _loading = false;
        });
        if (item != null) _fill(item);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _unitController.dispose();
    _totalController.dispose();
    _remainingController.dispose();
    _remindDaysController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _fill(StockItem item) {
    _nameController.text = item.name;
    _locationController.text = item.location;
    _unitController.text = item.unit;
    _totalController.text = StockpileFormat.num(item.totalQuantity);
    _remainingController.text = StockpileFormat.num(item.remainingQuantity);
    _remindDaysController.text = item.remindDays.toString();
    _noteController.text = item.note;

    _purchaseDate = item.purchaseDate;
    _expiryDate = item.expiryDate;
    _hasExpiry = item.expiryDate != null;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.itemId != null;
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: isEdit ? '编辑物品' : '新增物品',
        showBackButton: true,
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _buildFormCard(
                    title: '名称',
                    child: _buildTextField(
                      key: const ValueKey('stock_item_name'),
                      controller: _nameController,
                      placeholder: '如：牛奶、抽纸',
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTagSelector(),
                  const SizedBox(height: 12),
                  _buildFormCard(
                    title: '位置',
                    child: _buildTextField(
                      key: const ValueKey('stock_item_location'),
                      controller: _locationController,
                      placeholder: '如：冰箱、客厅',
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFormCard(
                    title: '数量',
                    compact: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildInlineLabeledField(
                            label: '总数量',
                            child: _buildTextField(
                              key: const ValueKey('stock_item_total'),
                              controller: _totalController,
                              placeholder: '',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildInlineLabeledField(
                            label: '剩余数量',
                            child: _buildTextField(
                              key: const ValueKey('stock_item_remaining'),
                              controller: _remainingController,
                              placeholder: '',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: _buildInlineLabeledField(
                            label: '单位',
                            child: _buildTextField(
                              key: const ValueKey('stock_item_unit'),
                              controller: _unitController,
                              placeholder: '如：盒',
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDateRow(
                    title: '采购日期',
                    value: StockpileFormat.date(_purchaseDate),
                    onTap: () => _pickDate(
                      initial: _purchaseDate,
                      onSelected: (v) => setState(() => _purchaseDate = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildExpirySection(),
                  const SizedBox(height: 12),
                  _buildFormCard(
                    title: '备注',
                    compact: true,
                    child: _buildTextField(
                      key: const ValueKey('stock_item_note'),
                      controller: _noteController,
                      placeholder: '可选',
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    '取消',
                    style: TextStyle(
                      color: IOS26Theme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: IOS26Theme.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: _save,
                  child: const Text(
                    '保存',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagSelector() {
    return Consumer<StockpileService>(
      builder: (context, service, _) {
        final tags = service.availableTags;
        if (tags.isEmpty) {
          return GlassContainer(
            padding: const EdgeInsets.all(12),
            child: const Text(
              '暂无可用标签，请先在「标签管理」中创建并关联到「囤货助手」',
              style: TextStyle(fontSize: 14, color: IOS26Theme.textSecondary),
            ),
          );
        }

        return GlassContainer(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '物品标签',
                style: TextStyle(fontSize: 13, color: IOS26Theme.textSecondary),
              ),
              const SizedBox(height: 10),
              for (final tag in tags) _buildTagRow(tag),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTagRow(Tag tag) {
    final id = tag.id;
    if (id == null) return const SizedBox.shrink();

    final selected = _selectedTagIds.contains(id);
    final dotColor = tag.color == null
        ? IOS26Theme.textTertiary
        : Color(tag.color!);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 6),
      onPressed: () {
        setState(() {
          if (selected) {
            _selectedTagIds.remove(id);
          } else {
            _selectedTagIds.add(id);
          }
        });
      },
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tag.name,
              style: const TextStyle(
                fontSize: 15,
                color: IOS26Theme.textPrimary,
              ),
            ),
          ),
          if (selected)
            const Icon(
              CupertinoIcons.check_mark_circled_solid,
              size: 20,
              color: IOS26Theme.primaryColor,
            )
          else
            const Icon(
              CupertinoIcons.circle,
              size: 20,
              color: IOS26Theme.textTertiary,
            ),
        ],
      ),
    );
  }

  Widget _buildExpirySection() {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '保质期/提醒',
                  style: TextStyle(
                    fontSize: 13,
                    color: IOS26Theme.textSecondary,
                  ),
                ),
              ),
              CupertinoSwitch(
                value: _hasExpiry,
                activeTrackColor: IOS26Theme.primaryColor,
                onChanged: (v) {
                  setState(() {
                    _hasExpiry = v;
                    if (!v) _expiryDate = null;
                    if (v && _expiryDate == null) {
                      _expiryDate = DateTime.now().add(const Duration(days: 7));
                    }
                  });
                },
              ),
            ],
          ),
          if (_hasExpiry) ...[
            const SizedBox(height: 10),
            _buildDateRow(
              title: '到期日期',
              value: _expiryDate == null
                  ? ''
                  : StockpileFormat.date(_expiryDate!),
              onTap: _expiryDate == null
                  ? null
                  : () => _pickDate(
                      initial: _expiryDate!,
                      onSelected: (v) => setState(() => _expiryDate = v),
                    ),
            ),
            const SizedBox(height: 10),
            _buildInlineLabeledField(
              label: '提前提醒天数',
              child: _buildTextField(
                key: const ValueKey('stock_item_remind_days'),
                controller: _remindDaysController,
                placeholder: '默认 3',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormCard({
    required String title,
    required Widget child,
    bool compact = false,
  }) {
    return GlassContainer(
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: IOS26Theme.textSecondary,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          child,
        ],
      ),
    );
  }

  Widget _buildInlineLabeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: IOS26Theme.textSecondary),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildDateRow({
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: IOS26Theme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: IOS26Theme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required Key key,
    required TextEditingController controller,
    String placeholder = '',
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: IOS26Theme.surfaceColor.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: CupertinoTextField(
        key: key,
        controller: controller,
        placeholder: placeholder,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: maxLines,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: null,
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        var temp = DateTime(initial.year, initial.month, initial.day);
        return Container(
          height: 300,
          color: IOS26Theme.surfaceColor,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        onSelected(temp);
                        Navigator.pop(context);
                      },
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: temp,
                  onDateTimeChanged: (value) => temp = value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: '请输入名称',
      );
      return;
    }

    final total = double.tryParse(_totalController.text.trim());
    final remaining = double.tryParse(_remainingController.text.trim());
    if (total == null || remaining == null) {
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: '请输入正确的数量',
      );
      return;
    }
    if (total < 0 || remaining < 0) {
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: '数量不能小于 0',
      );
      return;
    }
    if (remaining > total) {
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: '剩余数量不能大于总数量',
      );
      return;
    }

    int remindDays = 3;
    if (_hasExpiry) {
      remindDays = int.tryParse(_remindDaysController.text.trim()) ?? 3;
      if (remindDays < 0) {
        await StockpileDialogs.showMessage(
          context,
          title: '提示',
          content: '提醒天数不能小于 0',
        );
        return;
      }
    }

    final now = DateTime.now();
    final editing = _editing;
    int? itemId;

    try {
      if (editing == null) {
        itemId = await _service.createItem(
          StockItem.create(
            name: name,
            location: _locationController.text,
            unit: _unitController.text,
            totalQuantity: total,
            remainingQuantity: remaining,
            purchaseDate: _purchaseDate,
            expiryDate: _hasExpiry ? _expiryDate : null,
            remindDays: remindDays,
            note: _noteController.text,
            now: now,
          ),
        );
      } else {
        itemId = editing.id;
        await _service.updateItem(
          editing.copyWith(
            name: name,
            location: _locationController.text.trim(),
            unit: _unitController.text.trim(),
            totalQuantity: total,
            remainingQuantity: remaining,
            purchaseDate: _purchaseDate,
            expiryDate: _hasExpiry ? _expiryDate : null,
            remindDays: remindDays,
            note: _noteController.text.trim(),
            updatedAt: now,
          ),
        );
      }

      if (itemId != null) {
        await _service.setTagsForItem(itemId, _selectedTagIds.toList());
      }
    } catch (e) {
      if (!mounted) return;
      await StockpileDialogs.showMessage(
        context,
        title: '保存失败',
        content: e.toString(),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }
}
