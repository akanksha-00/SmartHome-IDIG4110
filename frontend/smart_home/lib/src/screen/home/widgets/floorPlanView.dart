import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

class FloorPlanView extends StatefulWidget {
  const FloorPlanView({
    super.key,
    this.selectedRoom = 'living',
    this.onRoomSelected,
    this.onResetReady,
  });

  final String selectedRoom;
  final ValueChanged<String>? onRoomSelected;
  final ValueChanged<VoidCallback>? onResetReady;

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
  three.Object3D? _houseModel;

  final Map<String, String> _roomObjectNames = {
    'living': 'livingRoom',
    'kitchen': 'kitchen',
    'bedroom1': 'bedroom1',
    'bathroom1': 'bathroom1',
  };

  final _raycaster = three.Raycaster();

  final Map<three.Mesh, three.Material> _floorMaterials = {};

  Offset? _pointerDownPosition;
  bool _pointerDragged = false;

  @override
  void initState() {
    super.initState();

    _threeJs = three.ThreeJS(
      settings: three.Settings(
        clearColor: 0x09090B,
        antialias: true,
        toneMapping: three.ACESFilmicToneMapping,
        toneMappingExposure: 1.0,
        enableShadowMap: false,
      ),
      setup: () async {
        _camera.aspect = _threeJs.width / _threeJs.height;
        _camera.updateProjectionMatrix();

        _camera.position.setValues(10, 8, 12);
        _camera.lookAt(three.Vector3.zero());

        _scene.add(
          three.HemisphereLight(0xFFFFFF, 0x334155, 0.4),
        );

        final sunlight = three.DirectionalLight(0xffffff, 1.0);
        sunlight.position.setValues(5, 8, 5);
        sunlight.castShadow = true;
        sunlight.shadow!.mapSize.setValues(2048, 2048);
        sunlight.shadow!.camera = three.OrthographicCamera(
          -12,
          12,
          12,
          -12,
          0.5,
          50,
        );
        sunlight.shadow!.bias = -0.0005;
        _scene.add(sunlight);

        final loader = three.GLTFLoader();
        final model = await loader.fromAsset('assets/models/layout1.glb');

        if (model == null) {
          throw StateError('Could not load layout1.glb');
        }

        _houseModel = model.scene;
        _styleWalls();
        _scene.add(model.scene);
        _updateRoomHighlight();
        loader.dispose();

        model.scene.traverse((object) {
          if (object is three.Mesh) {
            object.material = object.material?.clone();
            object.castShadow = true;
            object.receiveShadow = true;
          }
        });

        _controls = three.OrbitControls(
          _camera,
          _threeJs.globalKey,
        );

        _controls!.minDistance = 10;
        _controls!.maxDistance = 25;

        _threeJs.addAnimationEvent((dt) {
          _controls?.update();
        });
      },
      onSetupComplete: () {
        if (mounted) {
          widget.onResetReady?.call(_resetView);
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

  void _updateRoomHighlight() {
    for (final entry in _roomObjectNames.entries) {
      final room = _houseModel?.getObjectByName(entry.value);

      room?.traverse((object) {
        if (object is! three.Mesh) return;

        final originalMaterial = object.material;
        if (originalMaterial == null) return;

        final material = _floorMaterials.putIfAbsent(
          object,
          () => originalMaterial.clone(),
        );

        object.material = material;

        final colorHex = entry.key == widget.selectedRoom ? 0xFFB547 : 0x8795A3;

        material.color = three.Color.fromHex32(colorHex).convertSRGBToLinear();
      });
    }
  }

  @override
  void didUpdateWidget(covariant FloorPlanView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedRoom != widget.selectedRoom) {
      _updateRoomHighlight();
    }
  }

  void _selectRoomAt(Offset position, Size size) {
    if (_houseModel == null || size.isEmpty) return;

    final pointer = three.Vector2(
      (position.dx / size.width) * 2 - 1,
      -(position.dy / size.height) * 2 + 1,
    );

    _raycaster.setFromCamera(pointer, _camera);

    String? clickedRoom;
    double closestDistance = double.infinity;

    for (final entry in _roomObjectNames.entries) {
      final floor = _houseModel!.getObjectByName(entry.value);
      if (floor == null) continue;

      final hits = _raycaster.intersectObject(floor, true);
      if (hits.isEmpty) continue;

      if (hits.first.distance < closestDistance) {
        closestDistance = hits.first.distance;
        clickedRoom = entry.key;
      }
    }

    if (clickedRoom != null) {
      widget.onRoomSelected?.call(clickedRoom);
    }
  }

  void _styleWalls() {
    final walls = _houseModel?.getObjectByName('walls');

    walls?.traverse((object) {
      if (object is! three.Mesh) return;

      final originalMaterial = object.material;
      if (originalMaterial == null) return;

      final material = originalMaterial.clone();
      material.color = three.Color.fromHex32(0xE7EDF2).convertSRGBToLinear();

      object.material = material;
    });
  }

  void _resetView() {
    _camera.position.setValues(10, 8, 12);
    _controls?.target.setValues(0, 0, 0);
    _controls?.update();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constrains) {
      final view = ClipRect(
        child: Listener(
          onPointerDown: (event) {
            _pointerDownPosition =
                event.buttons == 1 ? event.localPosition : null;
            _pointerDragged = false;
          },
          onPointerMove: (event) {
            final start = _pointerDownPosition;

            if (start != null && (event.localPosition - start).distance > 6) {
              _pointerDragged = true;
            }
          },
          onPointerUp: (event) {
            final isClick = _pointerDownPosition != null && !_pointerDragged;
            _pointerDownPosition = null;

            if (isClick) {
              _selectRoomAt(event.localPosition, constrains.biggest);
            }
          },
          onPointerCancel: (event) {
            _pointerDownPosition = null;
          },
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: constrains.biggest,
            ),
            child: _threeJs.build(),
          ),
        ),
      );
      return view;
    });
  }
}
