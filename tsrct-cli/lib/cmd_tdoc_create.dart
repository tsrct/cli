import 'dart:async';

import 'package:args/command_runner.dart';

class TdocCreateCommand extends Command {
  @override
  String get description => "create tdoc of cls doc to embed text, images, etc.";

  @override
  String get name => "doc";

  TdocCreateCommand() {
    argParser
      ..addOption("uid",
        help: "uid of the document, if not provided, the system will generate one"
      )
      ..addOption("typ",
        allowed: ["text", "blob", "data"],
        allowedHelp: {
          "text": "text body, cty will be set to text/plain regardless of input",
          "blob": "binary body, such as an image or a pdf file; cty will have to be correctly set and will not be inferred",
          "data": "data body, such as a json or xml or csv document; cty will have to be correctly and will not be inferred",
        },
        mandatory: true,
        help: "type of the doc",
      )
      ..addOption("input",
        help: "file containing the information to be put in the tdoc; required for typ=blob or data",
      )
      ..addOption("output",
        help: "file to store the output; if not specified, output will be sent to stdout",
      )
      ..addOption("key",
        help: "key id to use for signing; by default cli will directly use kms if availble; if local key is used, then key and keypath must be supplied"
      )
      ..addOption("keypath",
        help: "path to the local key, if local keys are used; the value of 'key' indicating the key id must be provided"
      )
    ;

  }

  @override
  FutureOr<String> run() async {
    print(">> >> running command with args: ${argResults?.arguments}");
    return "";
  }
}