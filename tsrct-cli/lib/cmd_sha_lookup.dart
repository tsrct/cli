import 'dart:convert';

import 'package:tsrct_cli/utils.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';

class ShaLookupCommand extends TsrctCommand {
  @override
  String get description =>
      "lookup sha registry for provided file or checksum information";

  @override
  String get name => "lookup";

  ShaLookupCommand() {
    argParser.addOption(
      "file",
      mandatory: false,
      help: "file to checksum and lookup",
    );

    argParser.addOption(
      "checksum",
      aliases: ["cs"],
      mandatory: false,
      help: "a sha checksum in either hex or url encoded base64 to lookup",
    );
  }

  @override
  Future<void> runTsrctCommand() async {
    if (argResults == null) {
      return;
    }
    if (argResults!["file"] != null) {
      await handleFile(argResults!["file"]);
    } else if (argResults!["checksum"] != null) {
      await handleChecksum(argResults!["checksum"]);
    }
  }

  Future<void> handleFile(String fileName) async {
    String checksum = calculateBase64Checksum(fileName);
    await handleChecksum(checksum);
  }

  Future<void> handleChecksum(String checksum) async {
    print("checksum: $checksum");

    ApiResponse response = await tsrctApi.getShaRegistry(checksum);
    if (response.ok) {
      JsonEncoder encoder = JsonEncoder.withIndent("  ");
      print(encoder.convert(response.jsonResponse!));
    } else {
      print(
          "Error: ${response.jsonResponse!['errorCode']}: ${response.jsonResponse!['errorMessage']}");
    }
  }
}
