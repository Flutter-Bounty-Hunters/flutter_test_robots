import 'package:logging/logging.dart';
export 'package:logging/logging.dart';

abstract class FtrTestLogs {
  static final imeTestClientLog = Logger("ime.test-client");

  static final _activeLoggers = <Logger>{};

  static void initAllLogs(Level level) {
    initLoggers(level, {Logger.root});
  }

  static void initLoggers(Level level, Set<Logger> loggers) {
    hierarchicalLoggingEnabled = true;

    for (final logger in loggers) {
      if (!_activeLoggers.contains(logger)) {
        // ignore: avoid_print
        print('Initializing logger: ${logger.name}');
        logger
          ..level = level
          ..onRecord.listen(printLog);

        _activeLoggers.add(logger);
      }
    }
  }

  static void deactivateLoggers(Set<Logger> loggers) {
    for (final logger in loggers) {
      if (_activeLoggers.contains(logger)) {
        // ignore: avoid_print
        print('Deactivating logger: ${logger.name}');
        logger.clearListeners();

        _activeLoggers.remove(logger);
      }
    }
  }

  static void printLog(LogRecord record) {
    // ignore: avoid_print
    print(
        '(${record.time.second}.${record.time.millisecond.toString().padLeft(3, '0')}) ${record.loggerName} > ${record.level.name}: ${record.message}');
  }
}
