import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';


final autonomousModeProvider = StateProvider<String>((ref) => 'NONE');

class AutonomousModeSelector extends ConsumerWidget {
  AutonomousModeSelector({super.key});

  final Map<String, String> _autonomousModeDropdownOptions = {
    'NONE': 'Manual',
    'BALLAST': 'Auto ballast',
    'TRIMTAB': 'Auto Trimtab',
    'FULL': 'Full auto',
  };
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(autonomousModeProvider);
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      const Text("Auto mode:"),
      DropdownButton<String>(
        value: currentMode,
        dropdownColor: const Color.fromARGB(255, 255, 255, 255),
        onChanged: (String? newValue) {
          ref.read(autonomousModeProvider.notifier).state = newValue!;
        },
        items: _autonomousModeDropdownOptions.entries
            .map<DropdownMenuItem<String>>((MapEntry<String, String> entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value),
          );
        }).toList(),
      ),
    ]);
  }
}
