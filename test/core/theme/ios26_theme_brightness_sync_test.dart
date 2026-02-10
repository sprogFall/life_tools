import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';

class _ThemeInsensitiveProbe extends StatefulWidget {
  final ValueChanged<Color> onColorBuilt;

  const _ThemeInsensitiveProbe({required this.onColorBuilt});

  @override
  State<_ThemeInsensitiveProbe> createState() => _ThemeInsensitiveProbeState();
}

class _ThemeInsensitiveProbeState extends State<_ThemeInsensitiveProbe> {
  static int totalBuildCount = 0;

  @override
  Widget build(BuildContext context) {
    totalBuildCount += 1;
    final color = IOS26Theme.backgroundColor;
    widget.onColorBuilt(color);
    return ColoredBox(
      key: const ValueKey('theme_insensitive_probe'),
      color: color,
      child: const SizedBox(width: 12, height: 12),
    );
  }
}

void main() {
  testWidgets('亮度切换时应强制刷新非 Theme 依赖组件', (tester) async {
    final brightness = ValueNotifier<Brightness>(Brightness.light);
    Color? latestColor;
    _ThemeInsensitiveProbeState.totalBuildCount = 0;

    await tester.pumpWidget(
      ValueListenableBuilder<Brightness>(
        valueListenable: brightness,
        builder: (context, currentBrightness, _) {
          return Theme(
            data: ThemeData(brightness: currentBrightness),
            child: IOS26ThemeBrightnessSync(
              child: _ThemeInsensitiveProbe(
                onColorBuilt: (color) => latestColor = color,
              ),
            ),
          );
        },
      ),
    );

    expect(IOS26Theme.brightness, Brightness.light);
    expect(latestColor, const Color(0xFFF2F2F7));

    brightness.value = Brightness.dark;
    await tester.pump();

    expect(IOS26Theme.brightness, Brightness.dark);
    expect(latestColor, const Color(0xFF000000));
    expect(_ThemeInsensitiveProbeState.totalBuildCount, greaterThan(1));
  });
}
