import 'dart:async';

import 'package:flutter/widgets.dart';

/// 判断当前输入值是否存在处于激活态的 IME composing 区间。
///
/// 当中文输入法仍在拼音/候选组合阶段时，贸然覆盖文本可能导致输入法状态紊乱。
bool hasActiveImeComposing(TextEditingValue value) {
  final composing = value.composing;
  if (!composing.isValid || composing.isCollapsed) {
    return false;
  }
  if (composing.start < 0 || composing.end > value.text.length) {
    return false;
  }
  return true;
}

/// 仅在未处于 composing 阶段时写入文本。
///
/// 返回 `true` 表示已写入或无需变更；返回 `false` 表示因 composing 激活而跳过。
bool setControllerTextIfNoActiveComposing(
  TextEditingController controller,
  String nextText,
) {
  final current = controller.value;
  if (hasActiveImeComposing(current)) {
    return false;
  }
  if (current.text == nextText) {
    return true;
  }

  final selection = _clampSelection(
    current.selection,
    nextTextLength: nextText.length,
  );
  controller.value = current.copyWith(
    text: nextText,
    selection: selection,
    composing: TextRange.empty,
  );
  return true;
}

/// composing 激活时，延迟重试文本写入，直到 composing 结束或达到重试上限。
void setControllerTextWhenComposingIdle(
  TextEditingController controller,
  String nextText, {
  int maxRetries = 6,
  Duration retryDelay = const Duration(milliseconds: 16),
  bool Function()? shouldContinue,
}) {
  var retries = 0;

  void attempt() {
    if (shouldContinue != null && !shouldContinue()) {
      return;
    }

    final applied = setControllerTextIfNoActiveComposing(controller, nextText);
    if (applied || retries >= maxRetries) {
      return;
    }

    retries += 1;
    Timer(retryDelay, attempt);
  }

  attempt();
}

TextSelection _clampSelection(
  TextSelection selection, {
  required int nextTextLength,
}) {
  if (!selection.isValid) {
    return TextSelection.collapsed(offset: nextTextLength);
  }

  final baseOffset = selection.baseOffset.clamp(0, nextTextLength).toInt();
  final extentOffset = selection.extentOffset.clamp(0, nextTextLength).toInt();
  return TextSelection(
    baseOffset: baseOffset,
    extentOffset: extentOffset,
    affinity: selection.affinity,
    isDirectional: selection.isDirectional,
  );
}
