import 'dart:io';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';

late TsrctApi tsrctApi;

String? get userHomeDirectory =>
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

Future<Directory> get tsrctDirectory =>
    Directory("${userHomeDirectory!}/.tsrct").create();