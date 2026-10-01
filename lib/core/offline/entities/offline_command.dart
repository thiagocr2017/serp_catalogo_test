enum OfflineCommandStatus { pending, synced, conflict, failed }

class OfflineCommand {
  const OfflineCommand({
    required this.id,
    required this.commandType,
    required this.payload,
    required this.status,
    required this.deviceIdentifier,
    required this.createdAt,
    this.syncedAt,
    this.errorMessage,
    this.retryCount = 0,
  });

  final String id;
  final String commandType;
  final Map<String, dynamic> payload;
  final OfflineCommandStatus status;
  final String deviceIdentifier;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final String? errorMessage;
  final int retryCount;

  OfflineCommand copyWith({
    OfflineCommandStatus? status,
    DateTime? syncedAt,
    String? errorMessage,
    int? retryCount,
  }) => OfflineCommand(
    id: id,
    commandType: commandType,
    payload: payload,
    status: status ?? this.status,
    deviceIdentifier: deviceIdentifier,
    createdAt: createdAt,
    syncedAt: syncedAt ?? this.syncedAt,
    errorMessage: errorMessage ?? this.errorMessage,
    retryCount: retryCount ?? this.retryCount,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'commandType': commandType,
    'payload': payload,
    'status': status.name,
    'deviceIdentifier': deviceIdentifier,
    'createdAt': createdAt.toIso8601String(),
    'syncedAt': syncedAt?.toIso8601String(),
    'errorMessage': errorMessage,
    'retryCount': retryCount,
  };

  factory OfflineCommand.fromJson(Map<String, dynamic> json) => OfflineCommand(
    id: json['id'] as String,
    commandType: json['commandType'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    status: OfflineCommandStatus.values.byName(json['status'] as String),
    deviceIdentifier: json['deviceIdentifier'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    syncedAt: json['syncedAt'] == null ? null : DateTime.parse(json['syncedAt'] as String),
    errorMessage: json['errorMessage'] as String?,
    retryCount: json['retryCount'] as int? ?? 0,
  );
}
