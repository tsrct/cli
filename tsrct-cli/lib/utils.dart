import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';

late TsrctApi tsrctApi;

String? get userHomeDirectory =>
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

Future<Directory> get tsrctDirectory =>
    Directory("${userHomeDirectory!}/.tsrct").create();

abstract class TsrctCommand extends Command {


  @override
  Future<void> run() async {
    print('api endpoint: ${globalResults!["api"]}');
    tsrctApi = TsrctApi(globalResults!["api"]);
    runTsrctCommand();
  }

  Future<void> runTsrctCommand();

}