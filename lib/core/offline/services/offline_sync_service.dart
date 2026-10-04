import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../device/device_identity.dart';
import '../data/offline_queue_repository.dart';
import '../entities/offline_command.dart';

class OfflineSyncService extends Notifier<int> {
  OfflineSyncService(this._repository, this._device);

  final OfflineQueueRepository _repository;
  final DeviceIdentity _device;

  @override
  int build() => 0;

  bool get isSyncing => false;
  int get pendingCount => state;

  Future<void> enqueue({
    required String commandType,
    required Map<String, dynamic> payload,
  }) async {
    final command = OfflineCommand(
      id: const Uuid().v4(),
      commandType: commandType,
      payload: payload,
      status: OfflineCommandStatus.pending,
      deviceIdentifier: _device.identifier,
      createdAt: DateTime.now(),
    );
    await _repository.enqueue(command);
    state = await _repository.getPendingCount();
  }

  Future<void> sync() async {
    if (state < 0) return;

    try {
      final pending = await _repository.getPending();
      for (final command in pending) {
        await _syncCommand(command);
      }
    } finally {
      state = await _repository.getPendingCount();
    }
  }

  Future<void> _syncCommand(OfflineCommand command) async {
    try {
      final payload = Map<String, dynamic>.from(command.payload);
      payload['p_command_id'] = command.id;
      payload['p_actor_name'] = _device.actorName;
      payload['p_device_name'] = _device.name;
      payload['p_device_identifier'] = _device.identifier;

      await _executeCommand(command.commandType, payload);

      await _repository.updateStatus(command.id, OfflineCommandStatus.synced);
    } on Exception catch (e) {
      final isConflict =
          e.toString().contains('COMMAND_PAYLOAD_MISMATCH') ||
          e.toString().contains('VERSION_CONFLICT');

      if (isConflict) {
        await _repository.updateStatus(
          command.id,
          OfflineCommandStatus.conflict,
          errorMessage: e.toString(),
        );
      } else {
        await _repository.updateStatus(
          command.id,
          OfflineCommandStatus.failed,
          errorMessage: e.toString(),
          retryCount: command.retryCount + 1,
        );
      }
    }
  }

  Future<void> _executeCommand(
    String commandType,
    Map<String, dynamic> payload,
  ) async {
    final client = Supabase.instance.client;

    switch (commandType) {
      case 'create_payment':
        await client.rpc('create_payment', params: payload);
      case 'confirm_payment':
        await client.rpc('confirm_payment', params: payload);
      case 'cancel_payment':
        await client.rpc('cancel_payment', params: payload);
      case 'create_expense':
        await client.rpc('create_expense', params: payload);
      case 'transfer_between_accounts':
        await client.rpc('transfer_between_accounts', params: payload);
      case 'reserve_inventory':
        await client.rpc('reserve_inventory', params: payload);
      case 'release_reservation':
        await client.rpc('release_reservation', params: payload);
      case 'consume_reservation':
        await client.rpc('consume_reservation', params: payload);
      case 'create_and_confirm_inventory_document':
        await client.rpc(
          'create_and_confirm_inventory_document',
          params: payload,
        );
      default:
        throw Exception('Unknown command type: $commandType');
    }
  }

  Future<void> refreshPendingCount() async {
    state = await _repository.getPendingCount();
  }

  Future<List<OfflineCommand>> getAll() => _repository.getAll();

  Future<void> remove(String id) async {
    await _repository.remove(id);
    await refreshPendingCount();
  }

  Future<void> retry(String id) async {
    await _repository.updateStatus(
      id,
      OfflineCommandStatus.pending,
      retryCount: 0,
    );
    await sync();
  }
}

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  throw StateError('OfflineSyncService must be overridden.');
});
