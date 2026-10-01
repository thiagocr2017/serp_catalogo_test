import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../entities/offline_command.dart';

class OfflineQueueRepository {
  OfflineQueueRepository._();

  static final OfflineQueueRepository instance = OfflineQueueRepository._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    sqfliteFfiInit();
    final databaseFactory = databaseFactoryFfi;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/offline_queue.db';

    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE offline_commands (
              id TEXT PRIMARY KEY,
              command_type TEXT NOT NULL,
              payload TEXT NOT NULL,
              status TEXT NOT NULL,
              device_identifier TEXT NOT NULL,
              created_at TEXT NOT NULL,
              synced_at TEXT,
              error_message TEXT,
              retry_count INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      ),
    );
  }

  Future<void> enqueue(OfflineCommand command) async {
    final db = await database;
    await db.insert(
      'offline_commands',
      {
        'id': command.id,
        'command_type': command.commandType,
        'payload': jsonEncode(command.payload),
        'status': command.status.name,
        'device_identifier': command.deviceIdentifier,
        'created_at': command.createdAt.toIso8601String(),
        'synced_at': command.syncedAt?.toIso8601String(),
        'error_message': command.errorMessage,
        'retry_count': command.retryCount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OfflineCommand>> getPending() async {
    final db = await database;
    final rows = await db.query(
      'offline_commands',
      where: 'status = ?',
      whereArgs: [OfflineCommandStatus.pending.name],
      orderBy: 'created_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<OfflineCommand>> getAll() async {
    final db = await database;
    final rows = await db.query('offline_commands', orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList();
  }

  Future<void> updateStatus(
    String id,
    OfflineCommandStatus status, {
    String? errorMessage,
    int? retryCount,
  }) async {
    final db = await database;
    await db.update(
      'offline_commands',
      {
        'status': status.name,
        'synced_at': status == OfflineCommandStatus.synced
            ? DateTime.now().toIso8601String()
            : null,
        'error_message': errorMessage,
        'retry_count': retryCount,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> remove(String id) async {
    final db = await database;
    await db.delete('offline_commands', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM offline_commands WHERE status = ?',
      [OfflineCommandStatus.pending.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  OfflineCommand _fromRow(Map<String, dynamic> row) => OfflineCommand(
    id: row['id'] as String,
    commandType: row['command_type'] as String,
    payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
    status: OfflineCommandStatus.values.byName(row['status'] as String),
    deviceIdentifier: row['device_identifier'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    syncedAt: row['synced_at'] == null
        ? null
        : DateTime.parse(row['synced_at'] as String),
    errorMessage: row['error_message'] as String?,
    retryCount: row['retry_count'] as int? ?? 0,
  );
}
