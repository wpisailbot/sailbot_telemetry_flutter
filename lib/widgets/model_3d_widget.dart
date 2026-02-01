import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cube/flutter_cube.dart';

final rudderAngleProvider = StateProvider<double>((ref) => 0.0);
final trimtabAngleProvider = StateProvider<double>((ref) => 0.0);


class Model3DWidget extends ConsumerStatefulWidget {
  const Model3DWidget({super.key});

  @override
  ConsumerState<Model3DWidget> createState() => _Model3DWidgetState();
}

class _Model3DWidgetState extends ConsumerState<Model3DWidget> {
  late Object shark;
  late Object trimtabRods;
  late Object trimtab;
  late Object rudder1;
  late Object rudder2;


  @override
  void initState() {
    super.initState();
    // shark = Object(fileName: "assets/shark/shark.obj");
    // shark.rotation.setValues(0, 90, 0);
    // shark.updateTransform();

    // trimtabRods = Object(fileName: "assets/boat_models/trimtab_rods.obj");
    trimtabRods = Object(fileName: "assets/trimtab_rods/trimtabrod.obj");
    trimtabRods.position.setValues(-0.09,-0.16,0.42); 
    // trimtabRods.scale.setValues(0.2, 0.2, 0.2);
    trimtabRods.rotation.setValues(0, 0, 0); 
    trimtabRods.updateTransform();

    trimtab = Object(fileName: "assets/trimtab/trimtab.obj");
    trimtab.position.setValues(-0.1,-0.165,0.06); 
    // trimtab.scale.setValues(1.1,1.1,1.1);
    trimtab.rotation.setValues(0,120,0);
    trimtab.updateTransform();
    
    rudder1 = Object(fileName: "assets/rudder/rudder.obj");
    rudder1.position.setValues(-0.2, 0.1, 0); 
    rudder1.scale.setValues(0.8,0.8,0.8);
    rudder1.rotation.setValues(120, 70, 90);
    rudder1.updateTransform();
    
    rudder2 = Object(fileName: "assets/rudder/rudder.obj");
    rudder2.position.setValues(0.2, 0.1, 0);  
    rudder2.scale.setValues(0.8,0.8,0.8);
    rudder2.rotation.setValues(60, 110, 0);
    rudder2.updateTransform();
  }

  void _updateModelRotations(double rudderAngle, double trimtabAngle) {
    rudder1.rotation.z = 0 - 180/3.14*rudderAngle;
    rudder2.rotation.z = 0 - 180/3.14*rudderAngle;
    rudder1.updateTransform();
    rudder2.updateTransform();

    trimtab.rotation.y = 120 + 180/3.14*trimtabAngle;
    trimtab.updateTransform();
  }

  @override
  Widget build(BuildContext context) {
    final rudderAngle = ref.watch(rudderAngleProvider);
    final trimtabAngle = ref.watch(trimtabAngleProvider);

    // Update model rotations after watching providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateModelRotations(rudderAngle, trimtabAngle);
    });

    return Container(
      width: MediaQuery.of(context).size.width,   
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 185, 179, 179).withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color.fromARGB(255, 78, 78, 78)),
      ),
      child: Column(
        children: [
          // Top half - Trimtab and Rods
          Expanded(
            child: Container(
              color: Colors.grey[300],
              child: Cube(
                onSceneCreated: (Scene scene) {
                  scene.world.add(trimtabRods);
                  scene.world.add(trimtab);
                  scene.camera.zoom = 10;
                },
              ),
            ),
          ),
          
          // Divider
          Container(height: 2, color: Colors.black),
          
          // Bottom half - Rudders
          Expanded(
            child: Container(
              color: Colors.grey[400],
              child: Cube(
                onSceneCreated: (Scene scene) {
                  scene.world.add(rudder1);
                  scene.world.add(rudder2);
                  scene.camera.zoom = 10;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}