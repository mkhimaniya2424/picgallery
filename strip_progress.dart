import 'dart:io';

void main() {
  final file = File('lib/upload/new_upload_screen.dart');
  final lines = file.readAsLinesSync();
  
  final newLines = <String>[];
  bool skip = false;
  
  for (final line in lines) {
    if (line.contains('// STEP 2: ACTIVE PROGRESS')) {
      skip = true;
    }
    
    if (skip && line == '}') { // the end of the class
      skip = false;
      newLines.add('}');
      continue;
    }
    
    if (!skip) {
      newLines.add(line);
    }
  }
  
  file.writeAsStringSync(newLines.join('\n'));
}
