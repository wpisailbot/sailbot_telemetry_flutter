import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/utils/startup_manager.dart';

class TerminalWidget extends ConsumerWidget {
  const TerminalWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(logProvider);

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.black,
      child: ListView.builder(
        reverse: false, // To scroll to the bottom automatically
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[logs.length - 1 - index]; // Reverse the order
          final isError = log.contains('[ERROR]') || log.contains('[FATAL]');
          final isWarn = log.contains('[WARN]');
          return Text(
            log,
            style: TextStyle(
              color: isError ? Colors.red : isWarn? Colors.yellow: Colors.green,
            ),
          );
        },
      ),
    );
  }
}
