import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geotag_camera/camera/camera_controller_service.dart';

CameraDescription _cam(String name, CameraLensDirection d) =>
    CameraDescription(name: name, lensDirection: d, sensorOrientation: 90);

void main() {
  final cameras = [
    _cam('0', CameraLensDirection.back),
    _cam('1', CameraLensDirection.front),
    _cam('2', CameraLensDirection.back),
    _cam('3', CameraLensDirection.front),
  ];

  test('memilih entri pertama tiap arah', () {
    expect(pickCameraIndex(cameras, CameraLensDirection.back), 0);
    expect(pickCameraIndex(cameras, CameraLensDirection.front), 1);
  });

  test('null bila arah tidak ada', () {
    expect(pickCameraIndex([cameras[0]], CameraLensDirection.front), isNull);
  });
}
