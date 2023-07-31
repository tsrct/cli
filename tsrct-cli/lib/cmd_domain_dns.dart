import 'dart:convert';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:tsrct_cli/utils.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';

class DomainDnsCommand extends TsrctCommand {
  @override
  String get description =>
      "provide dns settings to allow domain initialization and registry with tsrct";

  @override
  String get name => "dns";

  DomainDnsCommand() {
    argParser.addOption(
      "key-set-id",
      mandatory: true,
      help:
          "the name to give the public key set that will be used as part of initialization; it must match the name of the created key; will be suffixed with -enc and -sig for the appropriate keys",
    );
    argParser.addOption(
      "uid",
      mandatory: true,
      help:
          "the 25 digit globally unique uid selected for this domain\nmust not be in use by any other entity;\nuse the 'tsrct init uid' command to check if your preferred uid is available",
    );
    argParser.addOption("key-host",
        mandatory: true,
        allowedHelp: {
          "local":
              "the key is located on the local file system; it must not have passphrase protection",
          "gcp":
              "the key is located in gcp cloud kms and the fully qualified location name is available"
        },
        help:
            "the hosted location of the key, whether local or a specific cloud kms such as gcp");
    argParser.addOption("sig-key-resource",
        mandatory: true,
        help:
            "the actual resource id of the signing key resource; if local, then the file path; if gcp, then the fully qualified gcp resource name including including project, region, keyring, keyname, and key version");
    argParser.addOption("enc-key-resource",
        mandatory: true,
        help:
            "the actual resource id of the encryption key resource; if local, then the file path; if gcp, then the fully qualified gcp resource name including project, region, keyring, keyname, and key version");
  }

  @override
  Future<void> runTsrctCommand() async {
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
      case "local":
        {
          keyActionsProvider = LocalKeyActionsProvider();
          break;
        }
    }

    await handleDns(keyActionsProvider, argResults!);

    return Future(() => null);
  }

  Future<void> handleDns(
    KeyActionsProvider keyActionsProvider,
    ArgResults argResults,
  ) async {
    String keySetId = argResults["key-set-id"];
    String sigResourceName = argResults["sig-key-resource"];
    String encResourceName = argResults["enc-key-resource"];

    Map<String, dynamic> jwks = await keyActionsProvider.getJWKS(
        keySetId, sigResourceName, encResourceName);

    print(">> >> jwks: $jwks");

    Map<String, dynamic> key0 = jwks["keys"][0];
    Map<String, dynamic> key1 = jwks["keys"][1];

    Map<String, dynamic> sigKey = key0["use"] == "sig" ? key0 : key1;
    Map<String, dynamic> encKey = key1["use"] == "enc" ? key1 : key0;

    String sigKeyFingerprint = "${sigKey['mod']}:${sigKey['exp']}";
    print('>> >> sigKeyFingerprint: $sigKeyFingerprint');
    Uint8List sigKeyFPBytes =
        Uint8List.fromList(utf8.encode(sigKeyFingerprint));

    String encKeyFingerprint = "${encKey['mod']}:${encKey['exp']}";
    print('>> >> encKeyFingerprint: $encKeyFingerprint');
    Uint8List encKeyFPBytes =
        Uint8List.fromList(utf8.encode(encKeyFingerprint));

    String sigKeyFPSignature =
        await keyActionsProvider.sign(sigResourceName, sigKeyFPBytes);
    String encKeyFPSignature =
        await keyActionsProvider.sign(sigResourceName, encKeyFPBytes);

    String txtRecordValue = "sig:$sigKeyFPSignature.enc:$encKeyFPSignature";
    print(">> >> full signed value is: $txtRecordValue");

    List<String> entries = [];
    int curr = 0;
    do {
      int limit = curr + 200 > txtRecordValue.length
          ? txtRecordValue.length
          : curr + 200;
      entries.add(txtRecordValue.substring(curr, limit));
      curr = limit;
    } while (curr < txtRecordValue.length);

    print("update domain dns entry with the following TXT records:");
    for (int i = 0; i < entries.length; i++) {
      print("tsrct-domain-verification[$i]=${entries[i]}");
    }

    keyActionsProvider.close();
  }
}
