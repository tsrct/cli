import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:tsrct_cli/utils.dart';

class UidAvailableCommand extends TsrctCommand {
  @override
  String get description => "check if a uid is available for selection";

  @override
  String get name => "avail";

  UidAvailableCommand() {}
  Future<void> runTsrctCommand() {
    String uidToCheck = argResults!.rest[0];
    print('>> >> uid to check: $uidToCheck');
    return Future(() => null);
  }
}
