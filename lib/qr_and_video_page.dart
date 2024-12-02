import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path/path.dart' as p;
import 'aws_service.dart';

class QRAndVideoPage extends StatefulWidget {
  final List<CameraDescription> cameras;

  QRAndVideoPage({required this.cameras});

  @override
  _QRAndVideoPageState createState() => _QRAndVideoPageState();
}

class _QRAndVideoPageState extends State<QRAndVideoPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;
  late CameraController _cameraController;

  bool isRecording = false;
  String? lastScannedQR;
  List<String> recordedVideos = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.medium,
      enableAudio: true,
    );
    await _cameraController.initialize();
    setState(() {});
  }

  Future<void> _startRecording(String qrData) async {
    final directory = await getApplicationDocumentsDirectory();
    final videoPath = '${directory.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      await _cameraController.startVideoRecording();
      setState(() {
        isRecording = true;
      });
      print('Bắt đầu quay video: $videoPath');
    } catch (e) {
      print('Lỗi khi bắt đầu quay video: $e');
    }
  }

  Future<void> _stopRecording(String qrCode) async {
    if (!_cameraController.value.isRecordingVideo) return;

    try {
      final file = await _cameraController.stopVideoRecording();
      setState(() {
        isRecording = false;
        recordedVideos.add(file.path);
      });

      await GallerySaver.saveVideo(file.path);
      print('Video đã lưu vào thư viện ảnh: ${file.path}');

      // Tải video lên AWS S3
      await AwsService.uploadVideoToAWS(file.path, qrCode);
    } catch (e) {
      print('Lỗi khi dừng quay video: $e');
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      qrController = controller;
    });

    controller.scannedDataStream.listen((scanData) async {
      if (scanData.code != lastScannedQR) {
        lastScannedQR = scanData.code;

        if (isRecording) {
          await _stopRecording(scanData.code ?? 'Unknown');
        } else {
          await _startRecording(scanData.code ?? 'Unknown');
        }
      }
    });
  }

  @override
  void dispose() {
    qrController?.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Quét QR và Quay Video'),
    ),
    body: Stack(
      children: [
        Positioned.fill(
          child: QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
          ),
        ),
        if (isRecording)
          Positioned(
            top: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.red,
                  radius: 10,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Đang quay...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
      ],
    ),
    floatingActionButton: isRecording
        ? FloatingActionButton(
            onPressed: () async {
              if (lastScannedQR != null) {
                await _stopRecording(lastScannedQR!);
              } else {
                print('QR chưa được quét. Không thể dừng quay.');
              }
            },
            backgroundColor: Colors.red,
            child: const Icon(Icons.stop),
          )
        : null,
  );
}
}