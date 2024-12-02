import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:aws_storage_service/aws_storage_service.dart';

class AwsService {
  static final AwsCredentialsConfig credentialsConfig = AwsCredentialsConfig(
    
  );

  static Future<void> uploadVideoToAWS(String filePath, String qrCode) async {
    try {
      UploadTaskConfig uploadConfig = UploadTaskConfig(
        credentailsConfig: credentialsConfig,
        url: 'videos/${p.basename(filePath)}',
        uploadType: UploadType.file,
        file: File(filePath),
      );

      UploadFile uploadFile = UploadFile(config: uploadConfig);
      uploadFile.uploadProgress.listen((event) {
        print('Tiến trình tải: ${event[0]} / ${event[1]}');
      });

      final uploadedUrl = await uploadFile.upload();
      print('Tải lên thành công: $uploadedUrl');
      uploadFile.dispose();
    } catch (e) {
      print('Lỗi tải lên AWS: $e');
    }
  }
}