import 'dart:async';

import 'package:args/args.dart';
import 'package:tsrct_cli/utils.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';

class ShaPublishCommand extends TsrctCommand {
  @override
  String get description =>
      "publish checksums to registry; the process is file --> bytes --> base64 --> bytes --> checksum";

  @override
  String get name => "pub";

  ShaPublishCommand() {
    argParser
      ..addOption(
        "input",
        mandatory: true,
        help: "file whose checksum is to be calculated and registered",
      )
      ..addOption(
        "output",
        help:
            "file to store the output; if not specified, output will be sent filename of src.uid",
      )
      ..addOption("key",
          mandatory: true,
          help:
              "keyset id to use for signing; by default cli will directly use kms if availble; if local key is used, then key and keypath must be supplied")
      ..addOption("sig-key-resource",
          mandatory: true,
          help:
              "the actual resource id of the signing key resource; if local, then the file path; if gcp, then the fully qualified gcp resource name including including project, region, keyring, keyname, and key version")
      ..addOption("key-host",
          mandatory: true,
          allowedHelp: {
            "local":
                "the key is located on the local file system; it must not have passphrase protection",
            "gcp":
                "the key is located in gcp cloud kms and the fully qualified location name is available"
          },
          help:
              "the hosted location of the key, whether local or a specific cloud kms such as gcp")
      ..addOption(
        "src",
        mandatory: true,
        help: "the 25 digit uid of the source org",
      );

    argParser.addOption("cid", mandatory: false);
    argParser.addOption("dsc", mandatory: false);
    argParser.addOption("emb",
        mandatory: false,
        help: "file containing the embedding vector for this file");
    argParser.addOption("exp", mandatory: false);
    argParser.addOption("nbf", mandatory: false);
    argParser.addOption("ref", mandatory: false);
    argParser.addOption("rid", mandatory: false);
    argParser.addOption("scm", mandatory: false);
    argParser.addOption("seq", mandatory: false);
    argParser.addOption("sub", mandatory: false);

    argParser.addOption("nam", mandatory: false, help: "name of the file");
    argParser.addOption("cty",
        mandatory: false, help: "content mime type of the file");
    argParser.addOption("uri",
        mandatory: false, help: "any uri for identification purposes");
  }

  Future<void> runTsrctCommand() async {
    print(">> >> running command with options: ${argResults?.options}");
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

    await handleCommand(keyActionsProvider, argResults!);
  }

  Future<void> handleCommand(
    KeyActionsProvider keyActionsProvider,
    ArgResults argResults,
  ) async {
    String src = argResults["src"];
    String cls = "sha";
    String uid = TsrctCommonOps.generateUid(src);

    String checksum = calculateBase64Checksum(argResults["input"]);

    Map<String, dynamic> header = {
      "cls": cls,
      "uid": uid,
      "mtd": {"sha": checksum},
    };

    String sigResourceName = argResults["sig-key-resource"];
    String sig = await keyActionsProvider.signDigest(
        sigResourceName, base64UrlDecode(checksum));

    Map<String, dynamic> shaBody = {
      "sha": checksum,
      "sig": sig,
      "key": argResults["key"],
    };
    populateHeader(shaBody, argResults, ["nam", "cty", "uri"]);
    String shaBodyBase64 = convertJsonToBase64(shaBody);

    List<String> items = [
      "cid",
      "dsc",
      "emb",
      "exp",
      "key",
      "nbf",
      "ref",
      "rid",
      "seq",
      "scm",
      "src",
      "sub"
    ];

    await populateHeader(header, argResults, items);

    TsrctDoc tsrctDoc = await TsrctCommonOps.buildSignedTsrctDoc(
      header,
      false,
      shaBodyBase64,
      sigResourceName,
      keyActionsProvider,
    );
    print('>> >> tdoc header: ${tsrctDoc.header}');

    ApiResponse docResponse =
        await tsrctApi.postTdoc(tsrctDoc.generateRawTdoc());
    if (!docResponse.ok) {
      print('>> >> doc response: ${docResponse.jsonResponse}');
    } else {
      print("tsrct doc created successfully: $uid");
      if (argResults.options.contains("output")) {
        writeTdocToFile(tsrctDoc, argResults["output"]);
      } else {
        writeTdocToFile(tsrctDoc, "$uid.tdoc");
      }
    }
  }
}
