import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:tsrct_cli/utils.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';

class UidAvailableCommand extends TsrctCommand {
  @override
  String get description => "check if a uid is available for selection";

  @override
  String get name => "avail";

  UidAvailableCommand() {}

  Future<void> runTsrctCommand() async {
    String uidToCheck = argResults!.rest[0];
    if(uidToCheck.length != 24) {
      print('Error: please enter a 24 digit id; a checksum will be added and checked for availability');
      return;
    }
    Map<String,dynamic> response = await tsrctApi.getChecksum(uidToCheck);
    if(response['status'] == 'ok') {
      int checksum = response['data']['checksum'];
      String uid = "$uidToCheck$checksum";
      print("uid with checksum: $uid");

      Map<String, dynamic> existsResponse = await tsrctApi.getUidExists(uid);
      if(existsResponse['status'] == 'ok') {
        Map<String,dynamic> existData = existsResponse['data'];
        bool isValidUid = existData['isChecksumValid'] && existData['uidValid'];
        if(isValidUid) {
          // uidExists is going to be present only if isChecksumValid and isTidValid are both true
          bool uidAvailable = !existData['uidExists'];

          if(uidAvailable) {
            print("Congrats! Your selected uid $uid is available!");
          }
          else {
            print("Sorry! Your selected uid $uid is not available!");
          }
        }
      }

    }
  }
}
