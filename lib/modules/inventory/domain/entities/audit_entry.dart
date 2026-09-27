class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.operation,
    required this.fieldName,
    required this.createdAt,
    this.oldValue,
    this.newValue,
    this.actorName,
    this.deviceName,
  });
  final String id;
  final String tableName;
  final String recordId;
  final String operation;
  final String fieldName;
  final String? oldValue;
  final String? newValue;
  final String? actorName;
  final String? deviceName;
  final DateTime createdAt;
}
