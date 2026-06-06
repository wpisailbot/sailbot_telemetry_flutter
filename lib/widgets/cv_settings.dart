import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';
import 'dart:developer' as dev;

class ObjectTypeDropdown extends StatelessWidget {
  final List<BuoyTypeInfo> buoyTypes;
  final BuoyTypeInfo selectedType;
  final Function(BuoyTypeInfo) onTypeChanged;

  const ObjectTypeDropdown({
    Key? key,
    required this.buoyTypes,
    required this.selectedType,
    required this.onTypeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropdownButton<BuoyTypeInfo>(
      value: selectedType,
      onChanged: (BuoyTypeInfo? newType) {
        if (newType != null) {
          onTypeChanged(newType);
        }
      },
      items: buoyTypes.map<DropdownMenuItem<BuoyTypeInfo>>((BuoyTypeInfo type) {
        return DropdownMenuItem<BuoyTypeInfo>(
          value: type,
          child: Text(type.name),
        );
      }).toList(),
    );
  }
}

final buoyDiameterProviders = <String, StateProvider<String>>{};

void initializeBuoyDiameterProviders(List<BuoyTypeInfo> buoyTypes) {
  for (var buoyType in buoyTypes) {
    if (!buoyDiameterProviders.containsKey(buoyType.name)) {
      buoyDiameterProviders[buoyType.name] = StateProvider<String>((ref) => buoyType.buoyDiameter.toString());
    }
  }
}

class HSVSliders extends ConsumerWidget {
  final HSVBounds hsvBounds;
  final StateProvider<String> buoyDiameterProvider;
  final Function(HSVBounds) onBoundsChanged;
  final Function(double) onDiameterChanged;

  const HSVSliders({
    Key? key,
    required this.hsvBounds,
    required this.buoyDiameterProvider,
    required this.onBoundsChanged,
    required this.onDiameterChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buoyDiameter = ref.watch(buoyDiameterProvider);
    return Column(
      children: <Widget>[
        SliderRow(
          label: "LH",
          value: hsvBounds.lowerH,
          onChanged: (value) {
            onBoundsChanged(hsvBounds..lowerH = value);
          },
        ),
        SliderRow(
          label: "LS",
          value: hsvBounds.lowerS,
          onChanged: (value) {
            onBoundsChanged(hsvBounds..lowerS = value);
          },
        ),
        SliderRow(
          label: "LV",
          value: hsvBounds.lowerV,
          onChanged: (value) {
            onBoundsChanged(hsvBounds..lowerV = value);
          },
        ),
        SliderRow(
          label: "UH",
          value: hsvBounds.upperH,
          onChanged: (value) {
            onBoundsChanged(hsvBounds..upperH = value);
          },
        ),
        SliderRow(
          label: "US",
          value: hsvBounds.upperS,
          onChanged: (value) {
            onBoundsChanged(hsvBounds..upperS = value);
          },
        ),
        SliderRow(
          label: "UV",
          value: hsvBounds.upperV,
          onChanged: (value) {
            onBoundsChanged(hsvBounds..upperV = value);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              const SizedBox(width: 25, child: Text("Dia", textAlign: TextAlign.center)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0)),
              Expanded(
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                  //border: OutlineInputBorder(),
                  //labelText: 'Diameter: $buoyDiameter',
                  hintText: buoyDiameter),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  onChanged: (value) {
                    ref.read(buoyDiameterProvider.notifier).state = value;
                    final parsedValue = double.tryParse(value) ?? 0;
                    onDiameterChanged(parsedValue);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final Function(double) onChanged;

  const SliderRow({
    Key? key,
    required this.label,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 25, child: Text(label, textAlign: TextAlign.center)),
        Expanded(
          child: Slider(
            activeColor: const Color.fromARGB(255, 0, 100, 255),
            value: value,
            max: 1,
            min: 0,
            onChanged: onChanged,
          ),
        ),
        Text((value * 255).toInt().toString()),
      ],
    );
  }
}

class CVSettings extends ConsumerStatefulWidget {
  const CVSettings({super.key});

  @override
  _CVSettingsState createState() => _CVSettingsState();
}

class _CVSettingsState extends ConsumerState<CVSettings> {
  CVParameters _currentParameters = CVParameters();
  BuoyTypeInfo? _selectedType;

  @override
  void initState() {
    super.initState();
    if (_currentParameters.buoyTypes.isNotEmpty) {
      _selectedType = _currentParameters.buoyTypes.first;
      initializeBuoyDiameterProviders(_currentParameters.buoyTypes);
    }
  }

  void _updateSelectedType(BuoyTypeInfo newType) {
    setState(() {
      _selectedType = newType;
    });
  }

  void _updateBounds(HSVBounds newBounds) {
    setState(() {
      _selectedType?.hsvBounds = newBounds;
      ref.read(networkCommsProvider)?.setCVParameters(_currentParameters);
    });
  }

  void _updateDiameter(double newDiameter) {
    setState(() {
      if (_selectedType != null) {
        ref.read(buoyDiameterProviders[_selectedType!.name]!.notifier).state = newDiameter.toString();
        _selectedType?.buoyDiameter = newDiameter;
        ref.read(networkCommsProvider)?.setCVParameters(_currentParameters);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    CVParameters? cvParameters = ref.watch(cvParametersProvider);
    if (cvParameters != null) {
      _currentParameters = cvParameters;
      if (_selectedType == null && _currentParameters.buoyTypes.isNotEmpty) {
        _selectedType = _currentParameters.buoyTypes.first;
        initializeBuoyDiameterProviders(_currentParameters.buoyTypes);
      }
    }

    final networkComms = ref.watch(networkCommsProvider);

    return Column(
      children: <Widget>[
        if (_selectedType != null)
          ObjectTypeDropdown(
            buoyTypes: _currentParameters.buoyTypes,
            selectedType: _selectedType!,
            onTypeChanged: _updateSelectedType,
          ),
        if (_selectedType != null)
          HSVSliders(
            hsvBounds: _selectedType!.hsvBounds,
            buoyDiameterProvider: buoyDiameterProviders[_selectedType!.name]!,
            onBoundsChanged: _updateBounds,
            onDiameterChanged: _updateDiameter,
          ),
        Row(
          children: [
            const SizedBox(width: 30, child: Text("CIR: ", textAlign: TextAlign.center)),
            Slider(
              activeColor: const Color.fromARGB(255, 0, 100, 255),
              value: _currentParameters.circularityThreshold,
              max: 1,
              min: 0,
              onChanged: (value) {
                setState(() {
                  _currentParameters.circularityThreshold = value;
                  dev.log("Setting cv parameters: $_currentParameters");
                  networkComms?.setCVParameters(_currentParameters);
                });
              },
            ),
            Text(_currentParameters.circularityThreshold.toStringAsFixed(3)),
          ],
        ),
      ],
    );
  }
}