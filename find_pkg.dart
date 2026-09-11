import 'dart:isolate';

void main() async {
  final uri = await Isolate.resolvePackageUri(
      Uri.parse('package:google_sign_in/google_sign_in.dart'));
  print('PATH: ${uri?.toFilePath()}');
}
