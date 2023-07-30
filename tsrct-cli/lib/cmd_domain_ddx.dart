import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';
import 'package:http/http.dart' as http;

class DomainDdxCommand extends Command {
  @override
  String get description =>
      "create a ddx entry for a target user or organization";

  @override
  String get name => "ddx-create";

  DomainDdxCommand() {
    argParser.addOption(
      "uid",
      mandatory: true,
      help: "a globally unique uid; this provided value will be concatenated to create a final uid of the form: src.tgt.uid",
    );
    argParser.addOption(
      "url",
      mandatory: true,
      help: "url endpoint where the org's ddx server is running",
    );
    argParser.addOption(
      "src",
      mandatory: true,
      help: "the 25 digit uid of the source org",
    );
    argParser.addOption(
      "tgt",
      mandatory: true,
      help: "the 25 digit uid of the target usr or org",
    );
    argParser.addOption(
      "key",
      mandatory: true,
      help:
          "the name of the key set registered with tsrct that will be used to sign the payloads",
    );
    argParser.addOption("key-host",
        mandatory: true,
        allowedHelp: {
          "local":
              "the key is located on the local file system; it must not have passphrase protection",
          "gcp":
              "the key is located in gcp cloud kms and the fully qualified location name is available"
        },
        help:
            "the hosted location of the key, whether local or a specific cloud kms such as gcp");
    argParser.addOption("sig-key-resource",
        mandatory: true,
        help:
            "the actual resource id of the signing key resource; if local, then the file path; if gcp, then the fully qualified gcp resource name including including project, region, keyring, keyname, and key version");
    argParser.addOption("scm",
        mandatory: true,
        help: "the fully qualified URI of the json schema location that the body conforms to");
    argParser.addOption("body",
        mandatory: true,
        help: "file name of the content to include in the ddx; this body must be a json document that conform to the schema indicated; NOTE: tsrct will not check for schema validation");
  }

  @override
  Future<void> run() async {
    String location = argResults?["key-host"];
    print('>> >> key-host: $location');

    late KeyActionsProvider keyActionsProvider;

    switch (location) {
      case "gcp":
        {
          keyActionsProvider = GCPKeyActionsProvider();
          await (keyActionsProvider as GCPKeyActionsProvider).init();
          break;
        }
    }

    await handleDdx(keyActionsProvider, argResults!);

    return Future(() => null);
  }

  Future<void> handleDdx(
    KeyActionsProvider keyActionsProvider,
    ArgResults argResults,
  ) async {
    String rid = argResults["rid"];
    String src = argResults["src"];
    String tgt = argResults["tgt"];
    String scm = argResults["scm"];
    String key = argResults["key"];
    String sigResourceName = argResults["sig-resource-name"];

    String url = argResults["url"];
    String ddxApiEndpoint = "$url/ddx/create";

    Uint8List fileBytes = File(argResults["body"]).readAsBytesSync();
    String fileBase64 = base64UrlEncode(fileBytes);

    Map<String,dynamic> header = {
      "cls": "ddx",
      "typ": "req",
      "key": "$src/$key",
      "src": src,
      "tgt": tgt,
      "scm": scm,
      "rid": rid,
      "uid": TsrctCommonOps.generateUid(src),
    };

    TsrctDoc ddxReqTdoc =
      await TsrctCommonOps.buildSignedTsrctDoc(
          header,
          false,
          fileBase64,
          sigResourceName,
          keyActionsProvider,
      );

    http.Response response = await http.post(
      Uri.parse(ddxApiEndpoint),
      body: ddxReqTdoc.generateRawTdoc(),
      encoding: utf8,
    );
    Map<String,dynamic> responseMap = json.decode(response.body);
    print('>> >> ddx response: $responseMap');

    return Future(() => null);
  }
}
