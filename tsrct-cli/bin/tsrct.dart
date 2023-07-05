import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:tsrct_cli/cmd_domain_dns.dart';
import 'package:tsrct_cli/cmd_domain_init.dart';
import 'package:tsrct_cli/cmd_key_init.dart';
import 'package:tsrct_cli/cmd_tdoc_create.dart';
import 'package:tsrct_cli/cmd_uid_available.dart';
import 'package:tsrct_cli/utils.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';

void main(List<String> arguments) {
  tsrctApi = TsrctApi(String.fromEnvironment("API_ENDPOINT"));
  print("api endpoint is: ${tsrctApi.apiEndpoint}");
  var runner = CommandRunner("tsrct", "command line tool for tsrct")
    ..addCommand(DomainCommand())
    ..addCommand(UidCommand())
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
    addSubcommand(TdocCreateCommand());
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

