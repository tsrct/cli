import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:tsrct_cli/utils.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';

class TdocCreateCommand extends Command {
  @override
  String get description =>
      "create tdoc of cls=doc to embed text, images, etc.";

  @override
  String get name => "doc";

  TdocCreateCommand() {
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
      ..addOption(
        "text",
        mandatory: false,
        help: "required if typ=text and input file is not provided"
      )
      ..addOption(
        "input",
        help:
            "file containing the information to be put in the tdoc; required for typ=blob or data or json, and if typ=text with no text argument",
      )
      ..addOption(
        "output",
        help:
            "file to store the output; if not specified, output will be sent to stdout",
      )

      ..addOption(
          "key",
          help:
              "keyset id to use for signing; by default cli will directly use kms if availble; if local key is used, then key and keypath must be supplied")
      ..addOption(
          "sig-key-resource",
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

    argParser.addOption("src",
      mandatory: true,
      help: "the 25 digit uid of the source org",
    );

    argParser.addOption("tgt", mandatory: false);
    argParser.addOption("cid", mandatory: false);
    argParser.addOption("cty", mandatory: false, help: "required with typ=blob or data");
    argParser.addOption("dsc", mandatory: false);
    argParser.addOption("exp", mandatory: false);
    argParser.addOption("ref", mandatory: false);
    argParser.addOption("rid", mandatory: false);
    argParser.addOption("scm", mandatory: false);
    argParser.addOption("seq", mandatory: false);
    argParser.addOption("sub", mandatory: false);

  }

  @override
  Future<void> run() async {
    print(">> >> running command with args: ${argResults?.arguments}");
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

  Future<void> handleCommand (
      KeyActionsProvider keyActionsProvider,
      ArgResults argResults,
  ) async {
    String src = argResults["src"];
    String typ = argResults["typ"];
    String cty = "";
    switch(typ) {
      case "text": cty = "text/plain"; break;
      case "json": cty = "application/json"; break;
      default: cty = argResults["cty"]; break;
    }

    String uid = "";
    if(argResults.arguments.contains("uid")) {
      uid = "$src.${argResults['uid']}";
    }
    else {
      uid = TsrctCommonOps.generateUid(src);
    }

    String bodyBase64 = "";
    if(argResults.arguments.contains("text")) {
      bodyBase64 = convertStringToBase64(argResults["text"]);
    }
    else {
      bodyBase64 = _processFileToBase64(argResults["input"]);
    }
    print('>> >> body base 64: $bodyBase64');

    Map<String,dynamic> header = {
      "cls": "doc",
      "typ": typ,
      "cty": cty,
      "uid": uid,
    };
    List<String> items = ["key", "src", "tgt", "cid", "dsc", "exp", "rid", "scm", "seq", "sub"];
    for (String item in items) {
      _insertHeaderIfPresent(item, argResults, header);
    }
    print('>> >> options: ${argResults.options}');
    if(argResults.options.contains("ref")) {
      await _insertRefs(argResults["ref"], header);
    }

    String sigResourceName = argResults["sig-key-resource"];
    TsrctDoc tsrctDoc =
      await TsrctCommonOps.buildSignedTsrctDoc(
          header,
          false,
          bodyBase64,
          sigResourceName,
          keyActionsProvider,
      );
    print('>> >> tdoc header: ${tsrctDoc.header}');

    ApiResponse docResponse = await tsrctApi.postTdoc(tsrctDoc.generateRawTdoc());
    if(!docResponse.ok) {
      print('>> >> doc response: ${docResponse.jsonResponse}');
    }
    else {
      print("tsrct doc created successfully: $uid");
      if(argResults.options.contains("output")) {
        _writeTdocToFile(tsrctDoc, argResults["output"]);
      }
    }
  }
  
  Future<void> _insertRefs(String refs, Map<String,dynamic> header) async {
    ApiResponse refResponse = await tsrctApi.getRefs(refs);
    if(refResponse.ok) {
      Map<String,dynamic> data = refResponse.jsonResponse!;
      header["ref"] = data["data"];
    }
  }

  void _insertHeaderIfPresent(String item, ArgResults argResults, Map<String,dynamic> header) {
    if(argResults.options.contains(item)) {
      print('>> >> adding item[$item]: ${argResults[item]}');
      header[item] = argResults[item];
    }
  }

  String _processFileToBase64(String fileName) {
    File file = File(fileName);
    Uint8List fileBytes = file.readAsBytesSync();
    return base64UrlEncode(fileBytes);
  }

  void _writeTdocToFile(TsrctDoc tsrctDoc, String fileName) {
    fileName = "$fileName/${tsrctDoc.header["uid"]}";
    File file = File(fileName);
    file.writeAsStringSync(
        tsrctDoc.generateRawTdoc(),
        encoding: utf8,
        flush: true,
        mode: FileMode.write,
    );
    print('wrote file: $fileName');
  }

}
