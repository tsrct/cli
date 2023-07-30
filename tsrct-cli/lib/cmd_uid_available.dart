import 'package:args/args.dart';
import 'package:args/command_runner.dart';

class UidAvailableCommand extends Command {
  @override
  String get description => "check if a uid is available for selection";

  @override
  String get name => "avail";

  UidAvailableCommand() {}
  Future<void> run() {
    String uidToCheck = argResults!.rest[0];
    print('>> >> uid to check: $uidToCheck');
    return Future(() => null);
  }
}
