/// 拍照完成后的拍摄项选中策略。
///
/// 始终保持 [currentItemId]，不因当前项已达标而自动跳到其他未完成项；
/// 由用户自行选择下一项。
int resolveSelectedItemIdAfterCapture({required int currentItemId}) {
  return currentItemId;
}
