import 'dart:async';

import 'package:args/args.dart';
import 'package:tsrct_cli/utils.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';

class TdocCreateDocCommand extends TsrctCommand {
  @override
  String get description =>
      "create tdoc of cls=doc to embed text, images, etc.";

  @override
  String get name => "doc-create";

  TdocCreateDocCommand() {
    argParser
      ..addOption("uid",
          help:
              "uid of the document, if not provided, the system will generate one")
      ..addOption(
        "typ",
        allowed: ["text", "json", "blob", "data"],
        allowedHelp: {
          "text":
              "text body, cty will be set to text/plain regardless of input",
          "json":
              "json body, root should be object not array, therefore should be a {} not a []; cty must be application/json",
          "blob":
              "binary body, such as an image or a pdf file; cty will have to be correctly set and will not be inferred",
          "data":
              "data body, such as a json or xml or csv document; cty will have to be correctly and will not be inferred",
        },
        mandatory: true,
        help: "type of the doc",
      )
      ..addOption("text",
          mandatory: false,
          help: "required if typ=text and input file is not provided")
      ..addOption(
        "input",
        help:
            "file containing the information to be put in the tdoc; required for typ=blob or data or json, and if typ=text with no text argument",
      )
      ..addOption(
        "output",
        help:
            "file to store the output; if not specified, output will be sent filename of src.uid",
      )
      ..addOption("key",
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
              "the hosted location of the key, whether local or a specific cloud kms such as gcp");

    argParser.addOption(
      "src",
      mandatory: true,
      help: "the 25 digit uid of the source org",
    );
    argParser.addOption(
      "acl",
      mandatory: false,
      help: "the access control of the ddx, either acl_pub or acl_pri",
      allowedHelp: {
        "acl_pub": "ddx is public and can be viewed and validated by anyone",
        "acl_pri":
            "ddx is private and can be viewed and validate only by the src or tgt",
      },
      defaultsTo: "acl_pub",
    );
    argParser.addOption(
      "lst",
      mandatory: false,
      help:
          "make item listable if true, not listable if false; default is false (recommended)",
      allowedHelp: {
        "true":
            "if true, then if acl=acl_pub, the item is listable as an output of the org",
        "false":
            "if false, then regardless of acl, the item is not listable as an output of the org",
      },
      defaultsTo: "false",
    );

    argParser.addOption("cid", mandatory: false);
    argParser.addOption("cty",
        mandatory: false, help: "required with typ=blob or data");
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
    argParser.addOption("tgt", mandatory: false);
  }

  @override
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

    return Future(() => null);
  }

  Future<void> handleCommand(
    KeyActionsProvider keyActionsProvider,
    ArgResults argResults,
  ) async {
    String src = argResults["src"];
    String typ = argResults["typ"];
    String cty = "";
    switch (typ) {
      case "text":
        cty = "text/plain";
        break;
      case "json":
        cty = "application/json";
        break;
      default:
        cty = argResults["cty"];
        break;
    }

    String uid = "";
    if (argResults.options.contains("uid")) {
      uid = "$src.${argResults['uid']}";
    } else {
      uid = TsrctCommonOps.generateUid(src);
    }

    String bodyBase64 = "";
    if (argResults.options.contains("text")) {
      bodyBase64 = convertStringToBase64(argResults["text"]);
    } else {
      bodyBase64 = processFileToBase64(argResults["input"]);
    }
    print('>> >> body base 64: $bodyBase64');

    Map<String, dynamic> header = {
      "cls": "doc",
      "typ": typ,
      "cty": cty,
      "uid": uid,
    };

    List<String> items = [
      "acl",
      "key",
      "src",
      "ref",
      "emb",
      "tgt",
      "cid",
      "dsc",
      "exp",
      "nbf",
      "rid",
      "scm",
      "seq",
      "sub"
    ];
    await populateHeader(header, argResults, items);
    if (argResults["lst"] != null) {
      header["lst"] = "true" == argResults["lst"].toString().toLowerCase();
    } else {
      header["lst"] = false;
    }
    if (argResults["tgt"] != null) {
      header["acl"] = "acl_pri";
      header["lst"] = false;
    }

    String sigResourceName = argResults["sig-key-resource"];
    TsrctDoc tsrctDoc = await TsrctCommonOps.buildSignedTsrctDoc(
      header,
      false,
      bodyBase64,
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
