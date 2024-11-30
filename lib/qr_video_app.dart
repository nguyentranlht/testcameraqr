import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:video_player/video_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  MyApp({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: QRAndVideoPage(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

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

  Future<void> _stopRecording() async {
    if (!_cameraController.value.isRecordingVideo) return;

    try {
      final file = await _cameraController.stopVideoRecording();
      setState(() {
        isRecording = false;
        recordedVideos.add(file.path);
      });

      await GallerySaver.saveVideo(file.path);
      print('Video đã lưu vào thư viện ảnh: ${file.path}');
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
          await _stopRecording();
        }
        await _startRecording(scanData.code ?? 'Unknown');
      }
    });
  }

  void _endSession() async {
    if (isRecording) {
      await _stopRecording();
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoListPage(recordedVideos: recordedVideos),
      ),
    );
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
        actions: [
          TextButton(
            onPressed: _endSession,
            child: const Text(
              'Kết Thúc',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
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
    );
  }
}

class VideoListPage extends StatelessWidget {
  final List<String> recordedVideos;

  VideoListPage({required this.recordedVideos});

  void _deleteVideo(BuildContext context, int index) async {
    try {
      final file = File(recordedVideos[index]);
      if (await file.exists()) {
        await file.delete();
      }
      recordedVideos.removeAt(index);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa video ${index + 1}.'),
          duration: Duration(seconds: 2),
        ),
      );

      (context as Element).markNeedsBuild();
    } catch (e) {
      print('Lỗi khi xóa video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xóa video ${index + 1}.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh Sách Video'),
      ),
      body: ListView.builder(
        itemCount: recordedVideos.length,
        itemBuilder: (context, index) {
          final videoPath = recordedVideos[index];
          return ListTile(
            title: Text('Video ${index + 1}'),
            subtitle: Text(videoPath),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerPage(videoPath: videoPath),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Xác nhận'),
                        content: const Text('Bạn có chắc chắn muốn xóa video này?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Hủy'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteVideo(context, index);
                            },
                            child: const Text('Xóa'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final String videoPath;

  VideoPlayerPage({required this.videoPath});

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _videoPlayerController;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController.play();
      }).catchError((error) {
        print('Lỗi khi phát video: $error');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Lỗi'),
            content: const Text('Không thể phát video này.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xem Video'),
      ),
      body: Center(
        child: _videoPlayerController.value.isInitialized
            ? AspectRatio(
                aspectRatio: _videoPlayerController.value.aspectRatio,
                child: VideoPlayer(_videoPlayerController),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}