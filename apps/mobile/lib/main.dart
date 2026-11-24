import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app/darkvibex_app.dart';
import 'infra/crash_reporter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CrashReporter.install();
  runZonedGuarded(
    () => runApp(const DarkVibeXApp()),
    (error, stack) => CrashReporter.report(error.toString(), stack: stack),
  );
}
