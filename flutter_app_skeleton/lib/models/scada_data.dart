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

class ScadaControlReadiness {
  final bool ready;
  final String reason;

  const ScadaControlReadiness({
    required this.ready,
    required this.reason,
  });
}

class ScadaTelemetry {
  final String deviceId;
  final int timestamp;
  final int deviceTimestampMs;
  final int receivedAt;
  final int lruReceivedAt;
  final int comReceivedAt;
  final double sourceVoltage;
  final double loadVoltage;
  final String sourceVoltageStatus;
  final String loadVoltageStatus;
  final String sourceCurrentStatus;
  final String loadCurrentStatus;
  final double sourceCurrent;
  final double loadCurrent;
  final int quality;
  final String lruStatus;
  final String communicationStatus;
  final String lbsStatus;
  final String operationMode;
  final bool operationModeValid;
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
    this.lruReceivedAt = 0,
    this.comReceivedAt = 0,
    this.operationMode = 'UNKNOWN',
    this.operationModeValid = false,
    this.sourceVoltageStatus = 'UNKNOWN',
    this.loadVoltageStatus = 'UNKNOWN',
    this.sourceCurrentStatus = 'UNKNOWN',
    this.loadCurrentStatus = 'UNKNOWN',
  });

  bool get isStale => isStaleAt(DateTime.now().millisecondsSinceEpoch);

  bool isStaleAt(int nowMs) =>
      receivedAt <= 0 ||
      receivedAt > nowMs + 5000 ||
      nowMs - receivedAt > 15000;

  ScadaControlReadiness evaluateControlReadiness({
    required int nowMs,
  }) {
    bool isFreshTimestamp(int value) {
      return value > 0 && value <= nowMs + 5000 && nowMs - value <= 15000;
    }

    if (!isFreshTimestamp(receivedAt)) {
      return const ScadaControlReadiness(
        ready: false,
        reason: 'Telemetry sensor belum tersedia atau sudah kedaluwarsa.',
      );
    }

    if (quality != 0) {
      return ScadaControlReadiness(
        ready: false,
        reason: 'Kualitas data sensor bukan GOOD (quality=$quality).',
      );
    }

    if (lruStatus != 'NORMAL') {
      return ScadaControlReadiness(
        ready: false,
        reason: 'Status LRU bukan NORMAL ($lruStatus).',
      );
    }

    // Gateway mempertahankan status LRU selama sesi MQTT yang sama.
    // Timestamp LRU harus positif, tetapi tidak menggunakan TTL 15 detik.
    if (lruReceivedAt <= 0) {
      return const ScadaControlReadiness(
        ready: false,
        reason: 'Status LRU belum diterima pada sesi MQTT saat ini.',
      );
    }

    if (communicationStatus != 'NORMAL') {
      return ScadaControlReadiness(
        ready: false,
        reason: 'Status COM bukan NORMAL ($communicationStatus).',
      );
    }

    if (!isFreshTimestamp(comReceivedAt)) {
      return const ScadaControlReadiness(
        ready: false,
        reason: 'Heartbeat COM belum tersedia atau sudah kedaluwarsa.',
      );
    }

    return const ScadaControlReadiness(
      ready: true,
      reason: '',
    );
  }

  factory ScadaTelemetry.fromValue(String expectedDeviceId, Object? value) {
    if (value is! Map) {
      throw const FormatException('Telemetry must be an object.');
    }
    final data = Map<String, dynamic>.from(value);
    final timestamp = _integer(data, 'timestamp');
    final deviceTimestampMs = _integer(data, 'device_ts_ms');
    final receivedAt = _integer(data, 'received_at');
    final lruReceivedAt = data.containsKey('status_lru_received_at')
        ? _integer(data, 'status_lru_received_at')
        : 0;
    final comReceivedAt = data.containsKey('status_com_received_at')
        ? _integer(data, 'status_com_received_at')
        : 0;
    final quality = _integer(data, 'kualitas');
    final sourceVoltageStatus = _voltageStatus(data, 'status_v_sumber');
    final loadVoltageStatus = _voltageStatus(data, 'status_v_beban');
    final sourceCurrentStatus = _currentStatus(data, 'status_i_sumber');
    final loadCurrentStatus = _currentStatus(data, 'status_i_beban');
    final deviceId = data['device_id'];

    final operationMode =
        data.containsKey('mode_operasi') ? data['mode_operasi'] : 'UNKNOWN';
    final operationModeValid = data.containsKey('mode_operasi_valid')
        ? data['mode_operasi_valid']
        : false;

    const supportedOperationModes = <String>{
      'UNKNOWN',
      'STANDBY',
      'RUN',
      'INVALID',
    };

    if (deviceId != expectedDeviceId || quality < 0 || quality > 15) {
      throw const FormatException('Telemetry identity or quality is invalid.');
    }

    if (operationMode is! String ||
        !supportedOperationModes.contains(operationMode)) {
      throw const FormatException('Telemetry operation mode is invalid.');
    }

    if (operationModeValid is! bool) {
      throw const FormatException(
          'Telemetry operation mode validity is invalid.');
    }

    return ScadaTelemetry(
      deviceId: deviceId as String,
      timestamp: timestamp,
      deviceTimestampMs: deviceTimestampMs,
      receivedAt: receivedAt,
      lruReceivedAt: lruReceivedAt,
      comReceivedAt: comReceivedAt,
      sourceVoltage: _number(data, 'v_sumber'),
      loadVoltage: _number(data, 'v_beban'),
      sourceVoltageStatus: sourceVoltageStatus,
      loadVoltageStatus: loadVoltageStatus,
      sourceCurrentStatus: sourceCurrentStatus,
      loadCurrentStatus: loadCurrentStatus,
      sourceCurrent: _number(data, 'i_sumber'),
      loadCurrent: _number(data, 'i_beban'),
      quality: quality,
      lruStatus: _string(data, 'status_lru'),
      communicationStatus: _string(data, 'status_com'),
      lbsStatus: _string(data, 'status_lbs'),
      operationMode: operationMode,
      operationModeValid: operationModeValid,
    );
  }
}

class ScadaCommandResult {
  final String commandId;
  final CommandResultStatus status;
  final String dispatchState;
  final int updatedAt;
  final String detail;

  const ScadaCommandResult({
    required this.commandId,
    required this.status,
    this.dispatchState = 'unknown',
    required this.updatedAt,
    required this.detail,
  });

  String get operatorStateLabel {
    switch (dispatchState) {
      case 'validating':
        return 'RECEIVED · VALIDATING';
      case 'dry_run':
        return 'RECEIVED · DRY-RUN';
      case 'rejected':
        return 'REJECTED';
      case 'publishing':
        return 'EXECUTING · PUBLISHING';
      case 'sent':
        return 'EXECUTING · MQTT SENT (QoS 0)';
      case 'interrupted':
        return status == CommandResultStatus.indeterminate
            ? 'INDETERMINATE · DELIVERY TIDAK PASTI'
            : 'FAILED · VALIDASI TERHENTI';
      case 'failed':
        return 'FAILED · GAGAL SEBELUM MQTT PUBLISH';
      default:
        return '${status.name.toUpperCase()} · DISPATCH STATE UNKNOWN';
    }
  }

  String get operatorSafetyNote {
    switch (dispatchState) {
      case 'validating':
        return 'Gateway masih memvalidasi permintaan. Belum ada MQTT publish.';
      case 'dry_run':
        return 'DRY-RUN: tidak ada perintah kontrol yang dipublikasikan ke MQTT.';
      case 'rejected':
        return 'Gateway menolak permintaan sebelum MQTT publish. Perintah tidak dikirim.';
      case 'publishing':
        return 'Gateway sedang melakukan MQTT publish. Belum ada acknowledgement dari ESP32 atau PLC.';
      case 'sent':
        return 'MQTT QoS 0 PUBLISH telah diserahkan ke transport Gateway. Ini bukan konfirmasi penerimaan ESP32, eksekusi PLC, atau posisi fisik LBS.';
      case 'interrupted':
        if (status == CommandResultStatus.indeterminate) {
          return 'Jangan kirim ulang otomatis. Verifikasi umpan balik independen dan posisi LBS sebelum membuat permintaan baru.';
        }
        return 'Gateway terhenti saat validasi. MQTT publish belum dimulai. Periksa daftar command sebelum membuat permintaan baru.';
      case 'failed':
        return 'Gateway gagal sebelum MQTT publish. Tidak ada perintah kontrol yang dikirim.';
      default:
        return 'dispatch_state tidak tersedia. Status ini tidak membuktikan perintah telah dikirim atau dijalankan.';
    }
  }

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

    const allowedDispatchStates = <String>{
      'validating',
      'dry_run',
      'rejected',
      'publishing',
      'sent',
      'interrupted',
      'failed',
      'unknown',
    };

    final rawDispatchState = data['dispatch_state'];
    final String dispatchState;

    if (rawDispatchState == null) {
      // Kompatibilitas dengan hasil command lama.
      dispatchState = 'unknown';
    } else if (rawDispatchState is String &&
        allowedDispatchStates.contains(rawDispatchState)) {
      dispatchState = rawDispatchState;
    } else {
      throw const FormatException('Unsupported command dispatch state.');
    }

    return ScadaCommandResult(
      commandId: commandId,
      status: status,
      dispatchState: dispatchState,
      updatedAt: _integer(data, 'updated_at'),
      detail: _string(data, 'detail'),
    );
  }
}

String _voltageStatus(Map<String, dynamic> data, String key) {
  if (!data.containsKey(key)) return 'UNKNOWN';

  const allowed = <String>{'NORMAL', 'AC_OFF', 'SUSPECT', 'WARNING', 'UNKNOWN'};
  final value = data[key];
  if (value is! String || !allowed.contains(value)) {
    throw FormatException('Telemetry field "$key" has an invalid voltage status.');
  }
  return value;
}

String _currentStatus(Map<String, dynamic> data, String key) {
  if (!data.containsKey(key)) return 'UNKNOWN';

  const allowed = <String>{'NORMAL', 'SUSPECT', 'UNKNOWN'};
  final value = data[key];
  if (value is! String || !allowed.contains(value)) {
    throw FormatException('Telemetry field "$key" has an invalid current status.');
  }
  return value;
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
