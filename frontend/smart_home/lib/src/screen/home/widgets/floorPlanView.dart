import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

class FloorPlanView extends StatefulWidget {
  const FloorPlanView({super.key});

  @override
  State<FloorPlanView> createState() => _FloorPlanViewState();
}

class _FloorPlanViewState extends State<FloorPlanView> {
  final _scene = three.Scene();
  final _camera = three.PerspectiveCamera(
    45,
    1,
    0.1,
    100,
  );

  late final three.ThreeJS _threeJs;

  three.OrbitControls? _controls;

  @override
  void initState() {
    super.initState();

    _threeJs = three.ThreeJS(
      settings: three.Settings(clearColor: 0x09090B),
      setup: () async {
        _camera.aspect = _threeJs.width / _threeJs.height;
        _camera.updateProjectionMatrix();

        _camera.position.setValues(4, 3, 5);
        _camera.lookAt(three.Vector3.zero());

        final cube = three.Mesh(
          three.BoxGeometry(1.5, 1.5, 1.5),
          three.MeshNormalMaterial(),
        );

        _scene.add(three.AmbientLight(0xffffff, 0.6));

        final sunlight = three.DirectionalLight(0xffffff, 2.0);
        sunlight.position.setValues(5, 8, 5);

        final loader = three.GLTFLoader();
        final model = await loader.fromAsset('assets/models/testCube.glb');

        if (model == null) {
          throw StateError('Could not load testCube.glb');
        }

        _scene.add(model.scene);
        loader.dispose();

        _controls = three.OrbitControls(
          _camera,
          _threeJs.globalKey,
        );

        _threeJs.addAnimationEvent((dt) {
          _controls?.update();
        });
      },
      onSetupComplete: () {
        if (mounted) {
          setState(() {});
        }
      },
    );

    _threeJs.scene = _scene;
    _threeJs.camera = _camera;
  }

  @override
  void dispose() {
    _controls?.dispose();
    _threeJs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constrains) {
      return ClipRect(
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(size: constrains.biggest),
          child: _threeJs.build(),
        ),
      );
    });
  }
}
