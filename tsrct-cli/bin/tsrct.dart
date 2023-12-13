import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:tsrct_cli/cmd_domain_ddx_create.dart';
import 'package:tsrct_cli/cmd_domain_dns.dart';
import 'package:tsrct_cli/cmd_domain_init.dart';
import 'package:tsrct_cli/cmd_key_init.dart';
import 'package:tsrct_cli/cmd_tdoc_create.dart';
import 'package:tsrct_cli/cmd_uid_available.dart';
import 'package:tsrct_cli/utils.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';

void main(List<String> arguments) {
  // tsrctApi = TsrctApi(String.fromEnvironment("API_ENDPOINT"));
  // print("api endpoint is: ${tsrctApi.apiEndpoint}");
  var runner = CommandRunner("tsrct", "command line tool for tsrct")
    ..argParser.addOption("api", defaultsTo: "https://api.tsrct.io")
    ..addCommand(DomainCommand())
    ..addCommand(UidCommand())
    ..addCommand(TdocCommand())
    ..addCommand(SwapperCommand())
    ..run(arguments).catchError((error) {
      if (error is! UsageException) throw error;
      print(error);
      exit(64); // Exit code 64 indicates a usage error.
    });
}

/// domain command -- domain related commands
class DomainCommand extends Command {
  @override
  String get description => "domain related operations for an organization";

  @override
  String get name => "domain";

  DomainCommand() {
    addSubcommand(DomainDnsCommand());
    addSubcommand(DomainInitCommand());
    addSubcommand(DomainDdxCreateCommand());
  }
}

class KeyCommand extends Command {
  @override
  String get description => "key related commands";

  @override
  String get name => "key";

  KeyCommand() {
    addSubcommand(KeyInitCommand());
  }
}

class TdocCommand extends Command {
  @override
  String get description => "manage tdoc operations";

  @override
  String get name => "tdoc";

  TdocCommand() {
    addSubcommand(TdocCreateDocCommand());
  }
}

class UidCommand extends Command {
  @override
  String get description => "uid related commands";

  @override
  String get name => "uid";

  UidCommand() {
    addSubcommand(UidAvailableCommand());
  }
}

class SwapperCommand extends Command {
  @override
  // TODO: implement description
  String get description => "swap one body for another";

  @override
  // TODO: implement name
  String get name => "swap";

  SwapperCommand() {
    argParser
      ..addOption("fake")
      ..addOption("orig");
  }

  @override
  Future<void> run() {
    String fake = argResults!['fake'];
    String orig = argResults!['orig'];

    Uint8List tdocBytes = File(orig).readAsBytesSync();
    String tdocString = utf8.decode(tdocBytes);
    TsrctDoc origTdoc = TsrctDoc.parse(tdocString);

    Uint8List fakeBytes = File(fake).readAsBytesSync();
    String fakeBase64 = base64UrlEncode(fakeBytes);
    origTdoc.bodyBase64 = fakeBase64;
    String fakeTdocBase64 = origTdoc.generateRawTdoc();

    String fakeName = "${orig.substring(0, orig.lastIndexOf("."))}-altered.tdoc";
    File fakeFile = File(fakeName);
    fakeFile.writeAsStringSync(
      fakeTdocBase64,
      encoding: utf8,
      flush: true,
      mode: FileMode.write,
    );
    print("wrote modified output: $fakeName");

    return Future(() => null);
  }
}