import 'dart:io';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';

late TsrctApi tsrctApi;

String? get userHomeDirectory =>
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

Future<Directory> get tsrctDirectory =>
    Directory("${userHomeDirectory!}/.tsrct").create();

abstract class TsrctCommand extends Command {

  void insertHeaderIfPresent(String item, ArgResults argResults, Map<String,dynamic> header) {
    if(argResults.options.contains(item)) {
      print('>> >> adding item[$item]: ${argResults[item]}');
      header[item] = argResults[item];
    }
  }

  Future<void> insertRefs(String refs, Map<String,dynamic> header) async {
    ApiResponse refResponse = await tsrctApi.getRefs(refs);
    if(refResponse.ok) {
      Map<String,dynamic> data = refResponse.jsonResponse!;
      header["ref"] = data["data"];
    }
  }

  Future<void> populateHeader(
      Map<String,dynamic> header,
      ArgResults argResults,
      List<String> items,
      ) async {
    for (String item in items) {
      insertHeaderIfPresent(item, argResults, header);
    }
    print('>> >> options: ${argResults.options}');
    if(argResults.options.contains("ref")) {
      await insertRefs(argResults["ref"], header);
    }
  }


  @override
  Future<void> run() async {
    print('api endpoint: ${globalResults!["api"]}');
    tsrctApi = TsrctApi(globalResults!["api"]);
    runTsrctCommand();
  }

  Future<void> runTsrctCommand();

}