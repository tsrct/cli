import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:tsrct_cli/utils.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';

class DownloadCommand extends TsrctCommand {
  @override
  String get description =>
      "download, verify, and extract tdocs from tsrct or other urls";

  @override
  String get name => "dl";

  DownloadCommand() {
    argParser.addOption(
      "url",
      mandatory: false,
      help:
          "url of where to download the file; either url or uid must be specified",
    );

    argParser.addOption(
      "uid",
      mandatory: false,
      help:
          "uid of tdoc to download from tsrct; either uid or url must be specified",
    );

    argParser.addOption(
      "loc",
      mandatory: false,
      help:
          "location and file of where to store the download; if not specified, the tsrct doc uid will be used as the filename",
    );

    argParser.addFlag(
      "extract",
      defaultsTo: true,
      negatable: true,
      help:
          "whether or not to extract the downloaded file; defaults to true, use --no-extract to not extract the file",
    );

    argParser.addFlag(
      "verify",
      defaultsTo: true,
      negatable: true,
      help:
          "whether or not to verify the downloaded file; defaults to true, use --no-verify to not verify file after download",
    );

    argParser.addOption(
      "out",
      mandatory: false,
      help:
          "name of output file after extract; defaults to name in the header if available, or uid+timestamp if none specified",
    );
  }

  @override
  Future<void> runTsrctCommand() async {
    if (argResults == null) {
      return;
    }
    bool isExtract = argResults!["extract"];
    bool isVerify = argResults!["verify"];
    String? url = argResults!["url"];
    String? uid = argResults!["uid"];
    if (url == null && uid == null) {
      print("Error: either one of 'url' or 'uid' must be provided");
      return;
    }
    if (url != null && url.isNotEmpty && uid != null && uid.isNotEmpty) {
      print("Error: only one of 'url' or 'uid' must be provided");
      return;
    }

    String? loc = argResults!["loc"];
    String? out = argResults!["out"];
    if (url != null && url.isNotEmpty) {
      await handleUrl(url, isExtract, isVerify, loc, out);
    } else {
      String api = globalResults!["api"];
      String uidUrl = "$api/$uid/tdoc";
      await handleUrl(uidUrl, isExtract, isVerify, loc, out);
    }
  }

  Future<void> handleUrl(String url, bool isExtract, bool isVerify, String? loc,
      String? out) async {
    String tempName = "tsrct-dl-${TsrctCommonOps.getNonce()}";
    File tempFile = File("${Directory.current.path}/$tempName");
    tempFile.create(recursive: true);

    http.Client client = http.Client();
    http.Response response = await client.get(Uri.parse(url));
    await tempFile.writeAsBytes(response.bodyBytes,
        mode: FileMode.write, flush: true);

    TsrctDoc tsrctDoc = TsrctDoc.parse(tempFile.readAsStringSync());
    String fileUid = tsrctDoc.header["uid"];
    String targetFileName = _determineTargetFileName(fileUid, loc);

    tempFile.copy(targetFileName);
    if (isVerify) {
      await _performVerification(tsrctDoc);
    }
    if (isExtract) {
      await _performExtract(fileUid, tsrctDoc, out);
    }

    print("Cleaning up ...");
    tempFile.deleteSync();
    print("Done.");
  }

  String _determineTargetFileName(String fileUid, String? loc) {
    if (loc != null && loc.isNotEmpty) {
      return "$loc.tdoc";
    }
    return "$fileUid.tdoc";
  }

  Future<void> _performVerification(TsrctDoc tsrctDoc) async {
    String key = tsrctDoc.header["key"];
    TsrctDoc? keyTsrctDoc =
        await TsrctCommonOps.getTsrctDocByUid(key, tsrctApi);
    if (keyTsrctDoc != null) {
      ValidationResult validationResult =
          TsrctCommonOps.validateTdoc(tsrctDoc, keyTsrctDoc);
      print(
          "Verification Result for uid[${tsrctDoc.header['uid']}] with key[$key] validates ${validationResult.ok}");
    } else {
      print("Error: key '$key' not found in the tsrct api");
    }
  }

  Future<void> _performExtract(
      String fileUid, TsrctDoc tsrctDoc, String? out) async {
    String cty = tsrctDoc.header["cty"] ?? "application/octet-stream";
    ApiResponse apiResponse = await tsrctApi.getFileExtension(cty);
    String ext = "unknown";
    if (apiResponse.ok) {
      String extension = apiResponse.jsonResponse!["data"]["extension"];
      if ("___" != extension) {
        ext = extension;
      }
    }

    if (out == null) {
      out = "${Directory.current.path}/$fileUid.$ext";
    } else {
      out = "$out.$ext";
    }

    Uint8List bodyBytes = base64UrlDecode(tsrctDoc.bodyBase64);
    print("Starting extract to file $out ...");
    File extractFile = File(out);
    extractFile.create(recursive: true);
    extractFile.writeAsBytesSync(bodyBytes);
    print("Done with extraction");
  }
}
