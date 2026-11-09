enum CommandResultStatus {
  received,
  executing,
  succeeded,
  failed,
  rejected,
  expired,
  indeterminate,
}

class ScadaCommand {
  final String commandId;
  final String target;
  final String action;
  final int createdAt;
  final String createdByUid;
  final String createdByName;
  final String status;

  const ScadaCommand({
    required this.commandId,
    required this.target,
    required this.action,
    required this.createdAt,
    required this.createdByUid,
    required this.createdByName,
    required this.status,
  });

  factory ScadaCommand.fromEntry(String commandId, Object? value) {
    if (value is! Map) {
      throw const FormatException('Command must be an object.');
    }
    final data = Map<String, dynamic>.from(value);
    final target = _string(data, 'target');
    final action = _string(data, 'action');
    if (target != 'LBS_01' ||
        (action != 'OPEN' && action != 'CLOSE') ||
        _string(data, 'status') != 'PENDING') {
      throw const FormatException('Command request is invalid.');
    }
    return ScadaCommand(
      commandId: commandId,
      target: target,
      action: action,
      createdAt: _integer(data, 'created_at'),
      createdByUid: _string(data, 'created_by_uid'),
      createdByName: _string(data, 'created_by_name'),
      status: 'PENDING',
    );
  }
}

class ScadaTelemetry {
  final String deviceId;
  final int timestamp;
  final int deviceTimestampMs;
  final int receivedAt;
  final double sourceVoltage;
  final double loadVoltage;
  final double sourceCurrent;
  final double loadCurrent;
  final int quality;
  final String lruStatus;
  final String communicationStatus;
  final String lbsStatus;

  const ScadaTelemetry({
    required this.deviceId,
    required this.timestamp,
    required this.deviceTimestampMs,
    required this.receivedAt,
    required this.sourceVoltage,
    required this.loadVoltage,
    required this.sourceCurrent,
    required this.loadCurrent,
    required this.quality,
    required this.lruStatus,
    required this.communicationStatus,
    required this.lbsStatus,
  });

  bool get isStale =>
      DateTime.now().millisecondsSinceEpoch - receivedAt > 15000;

  factory ScadaTelemetry.fromValue(String expectedDeviceId, Object? value) {
    if (value is! Map) {
      throw const FormatException('Telemetry must be an object.');
    }
    final data = Map<String, dynamic>.from(value);
    final timestamp = _integer(data, 'timestamp');
    final deviceTimestampMs = _integer(data, 'device_ts_ms');
    final receivedAt = _integer(data, 'received_at');
    final quality = _integer(data, 'kualitas');
    final deviceId = data['device_id'];
    if (deviceId != expectedDeviceId || quality < 0 || quality > 15) {
      throw const FormatException('Telemetry identity or quality is invalid.');
    }

    return ScadaTelemetry(
      deviceId: deviceId as String,
      timestamp: timestamp,
      deviceTimestampMs: deviceTimestampMs,
      receivedAt: receivedAt,
      sourceVoltage: _number(data, 'v_sumber'),
      loadVoltage: _number(data, 'v_beban'),
      sourceCurrent: _number(data, 'i_sumber'),
      loadCurrent: _number(data, 'i_beban'),
      quality: quality,
      lruStatus: _string(data, 'status_lru'),
      communicationStatus: _string(data, 'status_com'),
      lbsStatus: _string(data, 'status_lbs'),
    );
  }
}

class ScadaCommandResult {
  final String commandId;
  final CommandResultStatus status;
  final int updatedAt;
  final String detail;

  const ScadaCommandResult({
    required this.commandId,
    required this.status,
    required this.updatedAt,
    required this.detail,
  });

  factory ScadaCommandResult.fromValue(String commandId, Object? value) {
    if (value is! Map) {
      throw const FormatException('Command result must be an object.');
    }
    final data = Map<String, dynamic>.from(value);
    if (data['command_id'] != commandId) {
      throw const FormatException('Command result ID does not match request.');
    }
    final status = switch (data['status']) {
      'RECEIVED' => CommandResultStatus.received,
      'EXECUTING' => CommandResultStatus.executing,
      'SUCCEEDED' => CommandResultStatus.succeeded,
      'FAILED' => CommandResultStatus.failed,
      'REJECTED' => CommandResultStatus.rejected,
      'EXPIRED' => CommandResultStatus.expired,
      'INDETERMINATE' => CommandResultStatus.indeterminate,
      _ => throw const FormatException('Unsupported command result status.'),
    };

    return ScadaCommandResult(
      commandId: commandId,
      status: status,
      updatedAt: _integer(data, 'updated_at'),
      detail: _string(data, 'detail'),
    );
  }
}

double _number(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! num || !value.isFinite || value < 0) {
    throw FormatException('Telemetry field "$key" is invalid.');
  }
  return value.toDouble();
}

int _integer(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! num || !value.isFinite || value < 0 || value != value.toInt()) {
    throw FormatException('Field "$key" must be a non-negative integer.');
  }
  return value.toInt();
}

String _string(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Field "$key" must be a non-empty string.');
  }
  return value;
}
