import 'package:flutter/material.dart';
import 'video_player_page.dart';

class VideoListPage extends StatelessWidget {
  final List<String> recordedVideos;

  VideoListPage({this.recordedVideos = const []});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh Sách Video'),
      ),
      body: recordedVideos.isEmpty
          ? const Center(
              child: Text('Chưa có video nào được ghi.'),
            )
          : ListView.builder(
              itemCount: recordedVideos.length,
              itemBuilder: (context, index) {
                final videoPath = recordedVideos[index];
                return ListTile(
                  title: Text('Video ${index + 1}'),
                  subtitle: Text(videoPath),
                  trailing: IconButton(
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
                );
              },
            ),
    );
  }
}