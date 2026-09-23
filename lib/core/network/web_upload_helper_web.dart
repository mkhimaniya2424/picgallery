import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<dynamic> uploadFileWeb({
  required String blobUrl,
  required String uploadUrl,
  required String fileName,
  required String contentType,
  required Map<String, String> headers,
  Function(int, int)? onSendProgress,
}) async {
  final completer = Completer<dynamic>();
  try {
    // Fetch the blob from the object URL
    final response = await web.window.fetch(blobUrl.toJS).toDart;
    final blob = await response.blob().toDart;

    // Create FormData
    final formData = web.FormData();
    formData.append('file', blob, fileName);

    // Create XMLHttpRequest
    final xhr = web.XMLHttpRequest();
    xhr.open('POST', uploadUrl);

    // Set headers
    headers.forEach((key, value) {
      xhr.setRequestHeader(key, value);
    });

    // Handle progress
    if (onSendProgress != null) {
      xhr.upload.onprogress = ((web.ProgressEvent event) {
        if (event.lengthComputable) {
          onSendProgress(event.loaded, event.total);
        }
      }).toJS;
    }

    // Handle completion
    xhr.onload = ((web.Event _) {
      if (xhr.status >= 200 && xhr.status < 300) {
        completer.complete(xhr.responseText);
      } else {
        completer.completeError('Upload failed with status: ${xhr.status}');
      }
    }).toJS;

    xhr.onerror = ((web.Event _) {
      completer.completeError('Network error during upload');
    }).toJS;

    xhr.send(formData);
  } catch (e) {
    completer.completeError(e);
  }
  return completer.future;
}
