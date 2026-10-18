import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

class StatusLinkTile extends StatelessWidget {
  final String label;
  final LinkState state;
  final String? subtitle;

  const StatusLinkTile({
    super.key,
    required this.label,
    required this.state,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final bool normal = state == LinkState.normal;
    final bool fail = state == LinkState.fail;
    final String status = normal
        ? 'NORMAL'
        : fail
            ? 'FAIL'
            : 'Menunggu data…';
    final Color color = normal
        ? Colors.green
        : fail
            ? Colors.red
            : Colors.grey;
    final Widget leading = state == LinkState.unknown
        ? const Icon(Icons.hourglass_empty, color: Colors.grey, size: 46)
        : ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              normal
                  ? 'assets/images/status_link_normal.png'
                  : 'assets/images/status_link_warning.png',
              width: 46,
              height: 46,
              cacheWidth: 128,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                normal ? Icons.check_circle : Icons.warning_amber_rounded,
                color: color,
                size: 46,
              ),
            ),
          );

    return Card(
      color: color.withValues(alpha: 0.08),
      child: ListTile(
        leading: leading,
        title: Text(label),
        subtitle: Text(subtitle ?? status),
        trailing: Text(
          status,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
