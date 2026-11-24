import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/library/access.dart';
import 'package:unfurl/core/platform/platform.dart';
import 'package:unfurl/core/providers.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/design_system/buttons.dart';
import 'package:unfurl/features/viewer/access_view.dart';

const MethodChannel channel = MethodChannel('unfurl/platform');

void main() {
  late AppDatabase db;
  final List<MethodCall> calls = <MethodCall>[];
  Map<String, Object?> answers = <String, Object?>{};

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    calls.clear();
    answers = <String, Object?>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      MethodCall c,
    ) async {
      calls.add(c);
      return answers[c.method];
    });
  });

  tearDown(() => db.close());

  Future<(List<DocRef>, List<bool>)> pump(
    WidgetTester tester,
    FileAccess state, {
    String? at,
    String? sender,
    bool? exists,
    bool folderApp = true,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final List<DocRef> relinked = <DocRef>[];
    final List<bool> gone = <bool>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: AccessView(
            problem: AccessProblem(
              state: state,
              ref: const DocRef(uri: 'content://x/1', name: 'abc.pdf'),
              docId: at == null ? null : DocId(at),
              sender: sender,
              exists: exists,
              folderApp: folderApp,
              sdk: 36,
            ),
            onRelink: (DocRef r) async => relinked.add(r),
            onGone: () => gone.add(true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (relinked, gone);
  }

  List<String> actions(WidgetTester tester) =>
      tester.widgetList<AppButton>(find.byType(AppButton)).map((AppButton b) => b.label).toList();

  testWidgets('no access, location known: the truth, Allow this folder, Open in file manager', (
    WidgetTester tester,
  ) async {
    await pump(tester, FileAccess.noAccess, at: 'primary:Download/Reports/abc.pdf', exists: true);
    expect(find.textContaining('The file is still in Download › Reports'), findsOneWidget);
    expect(find.textContaining('only open files in folders you’ve allowed'), findsOneWidget);
    expect(find.textContaining('deleted'), findsNothing);
    expect(actions(tester), <String>['Allow this folder', 'Open in file manager', 'Remove from Recents']);
  });

  testWidgets('no access and Android can’t tell if it is there: nothing is claimed', (WidgetTester tester) async {
    await pump(tester, FileAccess.noAccess, at: 'primary:Docs/abc.pdf', folderApp: false);
    expect(find.textContaining('still in'), findsNothing);
    expect(actions(tester), <String>['Allow this folder', 'Remove from Recents']);
  });

  testWidgets('a folder Android won’t give: no Allow this folder', (WidgetTester tester) async {
    await pump(tester, FileAccess.noAccess, at: 'primary:Download/abc.pdf', exists: true);
    expect(find.textContaining('Android doesn’t let apps use that whole folder'), findsOneWidget);
    expect(actions(tester), <String>['Pick the file', 'Open in file manager', 'Remove from Recents']);
  });

  testWidgets('location unknown: names the sending app, offers no folder, never says it is gone', (
    WidgetTester tester,
  ) async {
    await pump(tester, FileAccess.unknown, sender: 'WhatsApp');
    expect(find.text('Open it again from WhatsApp'), findsOneWidget);
    expect(find.textContaining('can only be opened again from WhatsApp'), findsOneWidget);
    expect(find.textContaining('moved or deleted'), findsNothing);
    expect(actions(tester), <String>['Remove from Recents']);
  });

  testWidgets('location unknown and no sender: the app it was first opened from', (WidgetTester tester) async {
    await pump(tester, FileAccess.unknown);
    expect(find.textContaining('the app you first opened it from'), findsOneWidget);
  });

  testWidgets('gone: moved or deleted, and removing it from Recents', (WidgetTester tester) async {
    await pump(tester, FileAccess.gone, at: 'primary:Docs/abc.pdf', exists: false);
    expect(find.textContaining('It may have been moved or deleted'), findsOneWidget);
    expect(actions(tester).first, 'Remove from Recents');
    expect(find.text('Allow this folder'), findsNothing);
  });

  testWidgets('Allow this folder opens the picker there, relinks and opens', (WidgetTester tester) async {
    answers = <String, Object?>{
      'persistedFolders': <Object?>[],
      'pickFolder': <String, Object?>{'uri': 'content://tree/Docs', 'name': 'Docs', 'path': 'Docs'},
      'fileInFolder': 'content://tree/Docs/abc',
      'stat': <String, Object?>{'uri': 'content://tree/Docs/abc', 'name': 'abc.pdf', 'size': 9},
    };
    final (List<DocRef> relinked, _) = await pump(tester, FileAccess.noAccess, at: 'primary:Docs/abc.pdf');
    await tester.tap(find.text('Allow this folder'));
    await tester.pumpAndSettle();
    final MethodCall pick = calls.firstWhere((MethodCall c) => c.method == 'pickFolder');
    expect((pick.arguments as Map<Object?, Object?>)['initial'], 'primary:Docs');
    expect(relinked.single.uri, 'content://tree/Docs/abc');
    expect(calls.where((MethodCall c) => c.method == 'releaseFolder'), isEmpty);
  });

  testWidgets('a folder that doesn’t hold the file is given back and says so', (WidgetTester tester) async {
    answers = <String, Object?>{
      'persistedFolders': <Object?>[],
      'pickFolder': <String, Object?>{'uri': 'content://tree/Other', 'name': 'Other', 'path': 'Other'},
    };
    final (List<DocRef> relinked, _) = await pump(tester, FileAccess.noAccess, at: 'primary:Docs/abc.pdf');
    await tester.tap(find.text('Allow this folder'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(relinked, isEmpty);
    expect(calls.where((MethodCall c) => c.method == 'releaseFolder').length, 1);
    expect(find.textContaining('That folder doesn’t hold this file'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('allowed, and the file isn’t in it: gone', (WidgetTester tester) async {
    answers = <String, Object?>{
      'persistedFolders': <Object?>[],
      'pickFolder': <String, Object?>{'uri': 'content://tree/Docs', 'name': 'Docs', 'path': 'Docs'},
      'fileInFolder': 'content://tree/Docs/abc',
    };
    final (_, List<bool> gone) = await pump(tester, FileAccess.noAccess, at: 'primary:Docs/abc.pdf');
    await tester.tap(find.text('Allow this folder'));
    await tester.pumpAndSettle();
    expect(gone, <bool>[true]);
  });

  for (final (FileAccess s, String? at) in <(FileAccess, String?)>[
    (FileAccess.noAccess, 'primary:Download/Some long folder name/And another/abc.pdf'),
    (FileAccess.unknown, null),
    (FileAccess.gone, 'primary:Docs/abc.pdf'),
  ]) {
    testWidgets('$s fits at the largest font on a 360 dp phone', (WidgetTester tester) async {
      await pump(tester, s, at: at, sender: 'WhatsApp Business', exists: s != FileAccess.gone, scale: 2);
      expect(tester.takeException(), isNull);
    });
  }
}
