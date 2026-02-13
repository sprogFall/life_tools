import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release signing 配置应避免空配置并校验关键参数', () async {
    final gradleFile = File('android/app/build.gradle.kts');
    final content = await gradleFile.readAsString();

    // 回归约束：不要创建空 release signingConfig（该模式可能在构建期触发空路径异常）。
    expect(
      content.contains('if (!hasReleaseKeystore) return@create'),
      isFalse,
      reason: '不应在 create("release") 后通过 return 留下空签名配置',
    );

    // 关键签名参数应有显式校验，避免 Gradle 深层抛出不透明的 NPE。
    expect(
      content.contains('missingSigningProps'),
      isTrue,
      reason: '应校验 key.properties 的必填项是否完整',
    );
  });
}
