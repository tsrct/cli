import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';

late TsrctApi tsrctApi;

String? get userHomeDirectory =>
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

Future<Directory> get tsrctDirectory =>
    Directory("${userHomeDirectory!}/.tsrct").create();

abstract class TsrctCommand extends Command {
  void insertHeaderIfPresent(
      String item, ArgResults argResults, Map<String, dynamic> header) {
    if (argResults.options.contains(item)) {
      print('>> >> adding item[$item]: ${argResults[item]}');
      header[item] = argResults[item];
    }
  }

  Future<void> insertRefs(String refs, Map<String, dynamic> header) async {
    ApiResponse refResponse = await tsrctApi.getRefs(refs);
    if (refResponse.ok) {
      Map<String, dynamic> data = refResponse.jsonResponse!;
      header["ref"] = data["data"];
    }
  }

  Future<void> insertEmbs(String embs, Map<String, dynamic> header) async {
    List<String> embeds = embs.split(",");
    List<Map<String, dynamic>> embArray = List.empty(growable: true);
    for (String embed in embeds) {
      String embedInfo = File.fromUri(Uri.parse(embed)).readAsStringSync();
      Map<String, dynamic> emb = json.decode(embedInfo);
      embArray.add(emb);
    }
    header["emb"] = embArray;
  }

  Future<void> populateHeader(
    Map<String, dynamic> header,
    ArgResults argResults,
    List<String> items,
  ) async {
    print('>> >> options: ${argResults.options}');
    for (String item in items) {
      if (item == "ref") {
        if (argResults.options.contains("ref")) {
          await insertRefs(argResults["ref"], header);
        }
      } else if (item == "emb") {
        if (argResults.options.contains("emb")) {
          await insertEmbs(argResults["emb"], header);
        }
      } else {
        insertHeaderIfPresent(item, argResults, header);
      }
    }
  }

  String processFileToBase64(String fileName) {
    File file = File(fileName);
    Uint8List fileBytes = file.readAsBytesSync();
    return base64UrlEncode(fileBytes);
  }

  String calculateBase64Checksum(String fileName) {
    String fileBytesBase64 = processFileToBase64(fileName);
    Uint8List fileBase64Bytes = convertStringToBytes(fileBytesBase64);
    String checksum = TsrctCommonOps.sha256Digest(fileBase64Bytes);
    return checksum;
  }

  void writeTdocToFile(TsrctDoc tsrctDoc, String fileName) {
    // fileName = "$fileName/${tsrctDoc.header["uid"]}";
    File file = File(fileName);
    file.writeAsStringSync(
      tsrctDoc.generateRawTdoc(),
      encoding: utf8,
      flush: true,
      mode: FileMode.write,
    );
    print('wrote file: $fileName');
  }

  @override
  Future<void> run() async {
    print('api endpoint: ${globalResults!["api"]}');
    tsrctApi = TsrctApi(globalResults!["api"]);
    await runTsrctCommand();
  }

  Future<void> runTsrctCommand();
}
