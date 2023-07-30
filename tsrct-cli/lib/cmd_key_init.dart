import 'package:args/args.dart';
import 'package:args/command_runner.dart';

class KeyInitCommand extends Command {
  @override
  String get description =>
      "add a new key for the organization after initialization has already occurred";

  @override
  String get name => "init";

  KeyInitCommand() {
    argParser.addOption(
      "key",
      mandatory: true,
      help: "name of the key set that will be prefixed to the key names",
    );

    argParser.addOption("key-host",
        mandatory: true,
        allowedHelp: {
          // "local": "the key is located on the local file system; it will not have passphrase protection",
          "gcp":
              "the key is located in gcp cloud kms and the fully qualified location name is available"
        },
        help:
            "the hosted location of the key, whether local or a specific cloud kms such as gcp");
  }

  @override
  Future<void> run() {
    String location = argResults?["key-host"];
    print('>> >> key-host: $location');

    switch (location) {
      case "gcp":
        {
          break;
        }
      case "local":
        {
          handleLocal(argResults);
          break;
        }
    }

    return Future(() => null);
  }

  void handleLocal(ArgResults? argResults) {}
}
