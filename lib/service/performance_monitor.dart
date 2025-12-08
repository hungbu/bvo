
/// Performance monitoring service to track app performance during startup and runtime
class PerformanceMonitor {
  static final Map<String, List<OperationRecord>> _operations = {};
  static final Map<String, int> _queryCounts = {};
  static final Map<String, Duration> _queryDurations = {};
  static DateTime? _appStartTime;
  static final List<MemorySnapshot> _memorySnapshots = [];
  static final List<SlowOperation> _slowOperations = [];

  /// Start tracking app performance
  static void startApp() {
    _appStartTime = DateTime.now();
    _operations.clear();
    _queryCounts.clear();
    _queryDurations.clear();
    _memorySnapshots.clear();
    _slowOperations.clear();
    print('🚀 PerformanceMonitor: Started tracking app performance');
  }

  /// Track a database query
  static void trackDatabaseQuery(String sql, Duration duration, {String? method}) {
    final methodName = method ?? 'unknown';
    _queryCounts[methodName] = (_queryCounts[methodName] ?? 0) + 1;
    
    final totalDuration = _queryDurations[methodName] ?? Duration.zero;
    _queryDurations[methodName] = totalDuration + duration;

    final record = OperationRecord(
      name: 'DB Query: $methodName',
      duration: duration,
      timestamp: DateTime.now(),
      details: _sanitizeSql(sql),
      type: OperationType.database,
    );

    _operations.putIfAbsent(methodName, () => []).add(record);

    // Log slow queries (>50ms)
    if (duration.inMilliseconds > 50) {
      logSlowOperation('Database Query', duration, details: 'Method: $methodName\nSQL: ${_sanitizeSql(sql)}');
    }

    // Log all queries in debug mode
    if (duration.inMilliseconds > 10) {
      print('⏱️ DB Query [${methodName}]: ${duration.inMilliseconds}ms - ${_sanitizeSql(sql).substring(0, _sanitizeSql(sql).length > 100 ? 100 : _sanitizeSql(sql).length)}...');
    }
  }

  /// Track an async operation
  static void trackAsyncOperation(String name, Duration duration, {String? stackTrace, Map<String, dynamic>? metadata}) {
    final record = OperationRecord(
      name: name,
      duration: duration,
      timestamp: DateTime.now(),
      details: stackTrace,
      type: OperationType.async,
      metadata: metadata,
    );

    _operations.putIfAbsent(name, () => []).add(record);

    // Log slow operations (>100ms)
    if (duration.inMilliseconds > 100) {
      logSlowOperation(name, duration, details: stackTrace);
    }

    print('⏱️ Async [$name]: ${duration.inMilliseconds}ms');
  }

  /// Track memory usage at a specific point
  static void trackMemoryUsage(String label) {
    try {
      // Note: Flutter doesn't have direct memory access, but we can track object counts
      final snapshot = MemorySnapshot(
        label: label,
        timestamp: DateTime.now(),
        operationCount: _operations.length,
        queryCount: _queryCounts.values.fold<int>(0, (sum, count) => sum + count),
      );

      _memorySnapshots.add(snapshot);
      print('💾 Memory [$label]: ${snapshot.operationCount} operations, ${snapshot.queryCount} queries');
    } catch (e) {
      print('⚠️ Error tracking memory: $e');
    }
  }

  /// Log a slow operation
  static void logSlowOperation(String operation, Duration duration, {String? details}) {
    final slowOp = SlowOperation(
      operation: operation,
      duration: duration,
      timestamp: DateTime.now(),
      details: details,
    );

    _slowOperations.add(slowOp);
    
    print('🐌 SLOW OPERATION [$operation]: ${duration.inMilliseconds}ms');
    if (details != null && details.isNotEmpty) {
      print('   Details: ${details.substring(0, details.length > 200 ? 200 : details.length)}');
    }
  }

  /// Generate comprehensive performance report
  static Map<String, dynamic> generateReport() {
    final now = DateTime.now();
    final totalTime = _appStartTime != null 
        ? now.difference(_appStartTime!)
        : Duration.zero;

    // Calculate total query count and time
    final totalQueries = _queryCounts.values.fold<int>(0, (sum, count) => sum + count);
    final totalQueryTime = _queryDurations.values.fold<Duration>(
      Duration.zero,
      (sum, duration) => sum + duration,
    );

    // Find slowest operations
    final allOperations = <OperationRecord>[];
    _operations.values.forEach((ops) => allOperations.addAll(ops));
    allOperations.sort((a, b) => b.duration.compareTo(a.duration));

    // Group operations by type
    final dbOperations = allOperations.where((op) => op.type == OperationType.database).toList();
    final asyncOperations = allOperations.where((op) => op.type == OperationType.async).toList();

    // Find top slowest operations
    final topSlowOperations = allOperations.take(10).map((op) => {
      'name': op.name,
      'duration_ms': op.duration.inMilliseconds,
      'timestamp': op.timestamp.toIso8601String(),
      'details': op.details?.substring(0, op.details!.length > 100 ? 100 : op.details!.length),
    }).toList();

    // Find methods with most queries
    final topQueryMethods = _queryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'app_start_time': _appStartTime?.toIso8601String(),
      'report_generated_at': now.toIso8601String(),
      'total_time_ms': totalTime.inMilliseconds,
      'database': {
        'total_queries': totalQueries,
        'total_query_time_ms': totalQueryTime.inMilliseconds,
        'average_query_time_ms': totalQueries > 0 ? (totalQueryTime.inMilliseconds / totalQueries).round() : 0,
        'queries_by_method': _queryCounts.map((key, value) => MapEntry(key, {
          'count': value,
          'total_time_ms': _queryDurations[key]?.inMilliseconds ?? 0,
          'average_time_ms': value > 0 ? ((_queryDurations[key]?.inMilliseconds ?? 0) / value).round() : 0,
        })),
        'top_query_methods': topQueryMethods.take(10).map((e) => {
          'method': e.key,
          'count': e.value,
          'total_time_ms': _queryDurations[e.key]?.inMilliseconds ?? 0,
        }).toList(),
      },
      'operations': {
        'total_operations': allOperations.length,
        'database_operations': dbOperations.length,
        'async_operations': asyncOperations.length,
        'top_slow_operations': topSlowOperations,
      },
      'slow_operations': _slowOperations.map((op) => {
        'operation': op.operation,
        'duration_ms': op.duration.inMilliseconds,
        'timestamp': op.timestamp.toIso8601String(),
        'details': op.details?.substring(0, op.details!.length > 200 ? 200 : op.details!.length),
      }).toList(),
      'memory_snapshots': _memorySnapshots.map((snapshot) => {
        'label': snapshot.label,
        'timestamp': snapshot.timestamp.toIso8601String(),
        'operation_count': snapshot.operationCount,
        'query_count': snapshot.queryCount,
      }).toList(),
    };
  }

  /// Print performance report to console
  static void printReport() {
    final report = generateReport();
    
    print('\n' + '='*80);
    print('📊 PERFORMANCE REPORT');
    print('='*80);
    print('App Start Time: ${report['app_start_time']}');
    print('Report Generated: ${report['report_generated_at']}');
    print('Total Time: ${report['total_time_ms']}ms (${(report['total_time_ms'] / 1000).toStringAsFixed(2)}s)');
    print('');
    
    print('📊 DATABASE STATISTICS');
    print('-'*80);
    final db = report['database'] as Map<String, dynamic>;
    print('Total Queries: ${db['total_queries']}');
    print('Total Query Time: ${db['total_query_time_ms']}ms (${(db['total_query_time_ms'] / 1000).toStringAsFixed(2)}s)');
    print('Average Query Time: ${db['average_query_time_ms']}ms');
    print('');
    
    print('Top Query Methods:');
    final topMethods = db['top_query_methods'] as List;
    for (var i = 0; i < topMethods.length && i < 10; i++) {
      final method = topMethods[i] as Map<String, dynamic>;
      print('  ${i + 1}. ${method['method']}: ${method['count']} queries, ${method['total_time_ms']}ms total');
    }
    print('');
    
    print('🐌 SLOW OPERATIONS (>100ms)');
    print('-'*80);
    final slowOps = report['slow_operations'] as List;
    if (slowOps.isEmpty) {
      print('No slow operations detected.');
    } else {
      for (var i = 0; i < slowOps.length && i < 20; i++) {
        final op = slowOps[i] as Map<String, dynamic>;
        print('  ${i + 1}. ${op['operation']}: ${op['duration_ms']}ms');
      }
    }
    print('');
    
    print('⏱️ TOP 10 SLOWEST OPERATIONS');
    print('-'*80);
    final topSlow = report['operations']['top_slow_operations'] as List;
    for (var i = 0; i < topSlow.length; i++) {
      final op = topSlow[i] as Map<String, dynamic>;
      print('  ${i + 1}. ${op['name']}: ${op['duration_ms']}ms');
    }
    print('');
    
    print('='*80);
  }

  /// Get query count for a specific method
  static int getQueryCount(String method) {
    return _queryCounts[method] ?? 0;
  }

  /// Get total query count
  static int getTotalQueryCount() {
    return _queryCounts.values.fold<int>(0, (sum, count) => sum + count);
  }

  /// Sanitize SQL for logging (remove sensitive data, limit length)
  static String _sanitizeSql(String sql) {
    // Limit length and remove newlines for cleaner logs
    var sanitized = sql.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
    if (sanitized.length > 200) {
      sanitized = '${sanitized.substring(0, 200)}...';
    }
    return sanitized;
  }

  /// Reset all tracking data
  static void reset() {
    _operations.clear();
    _queryCounts.clear();
    _queryDurations.clear();
    _memorySnapshots.clear();
    _slowOperations.clear();
    _appStartTime = null;
  }
}

/// Record of a single operation
class OperationRecord {
  final String name;
  final Duration duration;
  final DateTime timestamp;
  final String? details;
  final OperationType type;
  final Map<String, dynamic>? metadata;

  OperationRecord({
    required this.name,
    required this.duration,
    required this.timestamp,
    this.details,
    required this.type,
    this.metadata,
  });
}

/// Type of operation
enum OperationType {
  database,
  async,
  memory,
  widget,
}

/// Memory snapshot at a point in time
class MemorySnapshot {
  final String label;
  final DateTime timestamp;
  final int operationCount;
  final int queryCount;

  MemorySnapshot({
    required this.label,
    required this.timestamp,
    required this.operationCount,
    required this.queryCount,
  });
}

/// Slow operation record
class SlowOperation {
  final String operation;
  final Duration duration;
  final DateTime timestamp;
  final String? details;

  SlowOperation({
    required this.operation,
    required this.duration,
    required this.timestamp,
    this.details,
  });
}

