import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:tsrct_cli/utils.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';
import 'package:http/http.dart' as http;

class DomainDdxCreateCommand extends TsrctCommand {
  @override
  String get description =>
      "create a ddx entry for a target user or organization";

  @override
  String get name => "ddx-create";

  DomainDdxCreateCommand() {
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
      "dom",
      mandatory: true,
      help: "the domain of the org that is registered against the src"
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
          "the name of the key set registered with tsrct that will be used to sign the payloads; this is the full key id",
    );
    argParser.addOption(
      "acl",
      mandatory: false,
      help: "the access control of the ddx, either acl_pub or acl_pri",
      allowedHelp: {
        "acl_pub": "ddx is public and can be viewed and validated by anyone",
        "acl_pri": "ddx is private and can be viewed and validate only by the src or tgt",
      },
      defaultsTo: "acl_pub",
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

    argParser.addOption("cid", mandatory: false);
    argParser.addOption("dsc", mandatory: false);
    argParser.addOption("exp", mandatory: false);
    argParser.addOption("nbf", mandatory: false);
    argParser.addOption("ref", mandatory: false);
    argParser.addOption("rid", mandatory: false);
    argParser.addOption("seq", mandatory: false);
    argParser.addOption("sub", mandatory: false);
  }

  @override
  Future<void> runTsrctCommand() async {
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
    String src = argResults["src"];
    String dom = argResults["dom"];
    String scm = argResults["scm"];
    String acl = argResults["acl"];
    String sigResourceName = argResults["sig-key-resource"];

    String url = argResults["url"];
    String ddxApiEndpoint = "$url/domain/$dom/ddx/create";

    Uint8List fileBytes = File(argResults["body"]).readAsBytesSync();
    String fileBase64 = base64UrlEncode(fileBytes);

    Map<String,dynamic> header = {
      "cls": "ddx",
      "typ": "grant",
      "cty": "application/json",
      "uid": TsrctCommonOps.generateUid(src),
      "nbf": TsrctCommonOps.getNowAsTdocDateFormat(),
    };

    List<String> items = ["key", "src", "tgt", "acl", "cid", "dsc", "exp", "nbf", "rid", "scm", "seq", "sub"];
    await populateHeader(header, argResults, items);

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