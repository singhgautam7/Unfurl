import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/motion/kit.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/design_system/buttons.dart';
import 'package:unfurl/design_system/sheets.dart';

Widget _app(VoidCallback Function(BuildContext) open, {double textScale = 1}) => MotionScope(
  level: MotionLevel.expressive,
  child: MaterialApp(
    theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
    builder: (BuildContext c, Widget? child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (BuildContext ctx) => TextButton(onPressed: open(ctx), child: const Text('open')),
      ),
    ),
  ),
);

void main() {
  testWidgets('the slide starts after the first frame, and slides rather than pops', (WidgetTester t) async {
    final List<double> builds = <double>[];
    await t.pumpWidget(
      _app(
        (BuildContext ctx) =>
            () => showAppBottomSheet<void>(
              context: ctx,
              title: 'Title',
              builder: (BuildContext c) {
                builds.add(ModalRoute.of(c)!.animation!.value);
                return const SizedBox(height: 120, child: Text('body'));
              },
            ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pump(); // route pushed, first frame builds the sheet
    expect(builds.first, 0);
    final Finder body = find.text('body');
    final double resting = t.view.physicalSize.height / t.view.devicePixelRatio; // off screen while the value is 0
    final double first = t.getTopLeft(body).dy;
    expect(first, greaterThanOrEqualTo(resting));
    await t.pump(const Duration(milliseconds: 16));
    await t.pump(const Duration(milliseconds: 16));
    final double a = t.getTopLeft(body).dy;
    await t.pump(const Duration(milliseconds: 60));
    final double b = t.getTopLeft(body).dy;
    expect(a, lessThan(first), reason: 'moving after the first frame');
    expect(b, lessThan(a), reason: 'still sliding up');
    await t.pumpAndSettle();
    expect(t.getTopLeft(body).dy, lessThan(b));
  });

  testWidgets('dismiss: a tap on the scrim closes it', (WidgetTester t) async {
    await t.pumpWidget(
      _app(
        (BuildContext ctx) =>
            () =>
                showAppBottomSheet<void>(context: ctx, title: 'Title', builder: (BuildContext c) => const Text('body')),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('body'), findsOneWidget);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(find.text('body'), findsNothing);
  });

  testWidgets('pushHeldSheet with a transparent barrier opens and pops', (WidgetTester t) async {
    await t.pumpWidget(
      _app(
        (BuildContext ctx) =>
            () => pushHeldSheet<void>(
              context: ctx,
              barrierColor: Colors.transparent,
              builder: (BuildContext c) => const Align(alignment: Alignment.bottomCenter, child: Text('held')),
            ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('held'), findsOneWidget);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(find.text('held'), findsNothing);
  });

  testWidgets('text scale 2.0 on 360x640: a long description and two actions do not overflow', (WidgetTester t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _app(
        textScale: 2,
        (BuildContext ctx) =>
            () => showAppBottomSheet<void>(
              context: ctx,
              title: 'Delete this highlight and its note',
              description: List<String>.filled(12, 'Unfurl never edits your files, so only the note goes.').join(' '),
              actions: <Widget>[
                AppButton(label: 'Delete highlight', onPressed: () {}),
                AppButton(label: 'Keep it', type: AppButtonType.secondary, onPressed: () {}),
              ],
              builder: (BuildContext c) => const SizedBox.shrink(),
            ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Keep it'), findsOneWidget);
  });
}
