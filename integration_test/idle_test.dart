// On-device guard: with a real library folder (the fixtures, problem files
// included), the app settles. Once the scan and enrichment are done, Home
// draws no frames and the database takes no writes while nobody touches it.
// Set up as for v3_test.dart, then build with
//
//   flutter build apk --profile --target-platform android-arm64 -t integration_test/idle_test.dart

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/library/library.dart';
import 'package:unfurl/core/providers.dart';

import 'harness.dart';

/// Counts every write the app makes.
class Writes extends QueryInterceptor {
  final List<String> log = <String>[];

  void _add(String s) => log.add(s.length > 120 ? s.substring(0, 120) : s);

  @override
  Future<int> runInsert(QueryExecutor executor, String statement, List<Object?> args) {
    _add(statement);
    return super.runInsert(executor, statement, args);
  }

  @override
  Future<int> runUpdate(QueryExecutor executor, String statement, List<Object?> args) {
    _add(statement);
    return super.runUpdate(executor, statement, args);
  }

  @override
  Future<int> runDelete(QueryExecutor executor, String statement, List<Object?> args) {
    _add(statement);
    return super.runDelete(executor, statement, args);
  }

  @override
  Future<void> runCustom(QueryExecutor executor, String statement, List<Object?> args) {
    _add(statement);
    return super.runCustom(executor, statement, args);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(pdfrxFlutterInitialize);

  testWidgets('with a real folder, Home settles: no frames and no writes while idle', (WidgetTester tester) async {
    final Writes writes = Writes();
    final AppDatabase db = AppDatabase(NativeDatabase.memory().interceptWith(writes));
    await boot(tester, const <String, Object>{}, db);
    final Library lib = container.read(libraryProvider);
    await lib.addPathFolder(fx, name: 'UnfurlFixtures', readable: '');
    await lib.refreshAll();
    // A cold scan and enrichment of the fixtures, then the app is left alone.
    await settle(tester, const Duration(seconds: 25));
    // A resume, as when the user comes back to the app.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester, const Duration(seconds: 15));

    final int before = writes.log.length;
    final List<FrameTiming> frames = <FrameTiming>[];
    void add(List<FrameTiming> f) => frames.addAll(f);
    SchedulerBinding.instance.addTimingsCallback(add);
    // Idle: real time passes with no pumping, so only frames the app asks
    // for itself are drawn.
    await Future<void>.delayed(const Duration(seconds: 10));
    SchedulerBinding.instance.removeTimingsCallback(add);
    final List<String> idle = writes.log.sublist(before);
    // ignore: avoid_print
    print('idle: ${frames.length} frames, ${idle.length} writes in 10 s; ${writes.log.length} writes in all');
    for (final String w in idle.take(10)) {
      // ignore: avoid_print
      print('idle write: $w');
    }
    expect(idle, isEmpty, reason: 'the database is written while nothing happens');
    expect(frames.length, lessThan(5), reason: 'Home keeps drawing while nothing happens');
  });
}
