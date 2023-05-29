import 'dart:io';

import 'package:test/test.dart';

void main() {
  String? userHome =
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

  print(">> >> user home: $userHome");

  Directory directory = Directory(userHome!);
  print(">> >> ${directory.path}");
  List<FileSystemEntity> files = directory.listSync();
  for (var file in files) {
    print(">> file: ${file.path}");
  }
}
