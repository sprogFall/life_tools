import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/ios26_theme.dart';
import '../models/stock_consumption.dart';
import '../models/stockpile_drafts.dart';
import '../services/stockpile_service.dart';
import '../utils/stockpile_utils.dart';

class StockConsumptionEditPage extends StatefulWidget {
  final int itemId;
  final StockConsumptionDraft? draft;

  const StockConsumptionEditPage({super.key, required this.itemId, this.draft});

  @override
  State<StockConsumptionEditPage> createState() =>
      _StockConsumptionEditPageState();
}

class _StockConsumptionEditPageState extends State<StockConsumptionEditPage> {
  late final StockpileService _service;

  final _qtyController = TextEditingController(text: '1');
  final _methodController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _consumedAt = DateTime.now();
  bool _loading = true;
  double? _remaining;
  String _itemName = '';

  @override
  void initState() {
    super.initState();
    _service = context.read<StockpileService>();
    final draft = widget.draft;
    if (draft != null) {
      _qtyController.text = StockpileFormat.num(draft.quantity);
      _methodController.text = draft.method;
      _noteController.text = draft.note;
      _consumedAt = draft.consumedAt;
    }
    Future<void>.microtask(_loadItem);
  }

  Future<void> _loadItem() async {
    final item = await _service.getItem(widget.itemId);
    if (!mounted) return;
    setState(() {
      _itemName = item?.name ?? '';
      _remaining = item?.remainingQuantity;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _methodController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(title: '记录消耗', showBackButton: true),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (_itemName.trim().isNotEmpty)
                    GlassContainer(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.cube_box_fill,
                            size: 18,
                            color: IOS26Theme.toolGreen,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _itemName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: IOS26Theme.textPrimary,
                              ),
                            ),
                          ),
                          if (_remaining != null)
                            Text(
                              '剩余：${StockpileFormat.num(_remaining!)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: IOS26Theme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  _buildTextField(
                    key: const ValueKey('stock_consumption_qty'),
                    controller: _qtyController,
                    placeholder: '消耗数量',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    key: const ValueKey('stock_consumption_method'),
                    controller: _methodController,
                    placeholder: '如何消耗（如：吃掉/用完/送人）',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  _buildDateTimeRow(
                    title: '消耗时间',
                    value: StockpileFormat.dateTime(_consumedAt),
                    onTap: _pickDateTime,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    key: const ValueKey('stock_consumption_note'),
                    controller: _noteController,
                    placeholder: '备注（可选）',
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
      ),
    );
  }

  Widget _buildTextField({
    required Key key,
    required TextEditingController controller,
    required String placeholder,
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

  Widget _buildDateTimeRow({
    required String title,
    required String value,
    required VoidCallback onTap,
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

  Future<void> _pickDateTime() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        var temp = _consumedAt;
        return Container(
          height: 320,
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
                        setState(() => _consumedAt = temp);
                        Navigator.pop(context);
                      },
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
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
    final qty = double.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: '请输入正确的消耗数量',
      );
      return;
    }

    final remaining = _remaining;
    if (remaining != null && qty > remaining) {
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: '消耗数量不能超过剩余库存',
      );
      return;
    }

    try {
      await _service.createConsumption(
        StockConsumption.create(
          itemId: widget.itemId,
          quantity: qty,
          method: _methodController.text,
          consumedAt: _consumedAt,
          note: _noteController.text,
          now: DateTime.now(),
        ),
      );
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
