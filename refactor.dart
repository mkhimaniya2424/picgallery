import 'dart:io';

void main() {
  final file = File('lib/upload/new_upload_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('UploadQueueScreen', 'NewUploadScreen');
  content = content.replaceAll('upload_queue_screen', 'new_upload_screen');
  content = content.replaceAll('UploadQueueState', 'NewUploadState');
  content = content.replaceAll('UploadQueueController', 'NewUploadNotifier');
  content = content.replaceAll('uploadQueueProvider', 'newUploadProvider');
  content = content.replaceAll('upload_queue_provider.dart', 'new_upload_provider.dart');
  
  // also need to import new_upload_provider and app_routes
  content = content.replaceAll("import 'upload_queue_provider.dart';", "import 'new_upload_provider.dart';\nimport 'upload_queue_provider.dart';");

  file.writeAsStringSync(content);
}
