import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';

import 'package:args/command_runner.dart';
import 'package:tsrct_cli/utils.dart';
import 'package:tsrct_dart_lib/tsrct_dart_lib.dart';

class DomainInitCommand extends TsrctCommand {
  @override
  String get description =>
      "initialize the domain for an org, which will essentially provision the org onto tsrct";

  @override
  String get name => "init";

  DomainInitCommand() {
    argParser.addOption(
      "dom",
      mandatory: true,
      help: "domain name to initialize",
    );
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

    await handleInit(keyActionsProvider, argResults!);

    return Future(() => null);
  }

  Future<void> handleInit(
    KeyActionsProvider keyActionsProvider,
    ArgResults argResults,
  ) async {
    String uid = argResults["uid"];
    String keySetId = argResults["key-set-id"];
    String sigResourceName = argResults["sig-key-resource"];
    String encResourceName = argResults["enc-key-resource"];

    Map<String, dynamic> jwks = await keyActionsProvider.getJWKS(
        keySetId, sigResourceName, encResourceName);
    print(">> >> jwks: $jwks");
    String jwksBodyBase64 = convertJsonToBase64(jwks);

    TsrctDoc synTdoc = await buildSynTdoc(
      keyActionsProvider,
      sigResourceName,
      argResults,
      jwksBodyBase64,
    );

    ApiResponse ackResponse = await sendSynData(synTdoc);

    try {
      if (ackResponse.ok) {
        Map<String, dynamic> data = ackResponse.jsonResponse!["data"];
        String ackTdoc = data["ack"];
        print(">> >> ackTdoc: \n$ackTdoc");

        TsrctDoc? ackTsrctDoc = await processAckTdoc(
          argResults,
          jwksBodyBase64,
          synTdoc,
          ackTdoc,
        );

        if (ackTsrctDoc == null) {
          throw Exception(">> >> ACK VALIDATION ERROR!!");
        }

        TsrctDoc regTsrctdoc = await _buildRegTdoc(
          argResults,
          keyActionsProvider,
          ackTsrctDoc,
        );

        TsrctDoc regKeyTsrctDoc = await _buildRegKeyTdoc(
          argResults,
          keyActionsProvider,
          jwksBodyBase64,
          ackTsrctDoc,
          regTsrctdoc,
        );

        Map<String, dynamic> registrationJson = {
          "reg": regTsrctdoc.generateRawTdoc(),
          "key": regKeyTsrctDoc.generateRawTdoc(),
        };

        ApiResponse regResponse = await tsrctApi.postJson(
          "/org/reg",
          registrationJson,
        );

        if (regResponse.ok) {
          //todo: save the ack and reg and key payloads locally
        } else {
          throw Exception(
              "Error with registration: ${regResponse.jsonResponse}");
        }
      } else {
        throw Exception("Error with ACK response: ${ackResponse.jsonResponse}");
      }
    } finally {
      keyActionsProvider.close();
    }
  }

  Future<TsrctDoc> buildSynTdoc(
    KeyActionsProvider keyActionsProvider,
    String sigResourceName,
    ArgResults argResults,
    String jwksBodyBase64,
  ) async {
    String dom = argResults["dom"];
    String keySetId = argResults["key-set-id"];
    String uid = argResults["uid"];

    Uint8List bodyBase64Bytes = Uint8List.fromList(utf8.encode(jwksBodyBase64));
    String sig =
        await keyActionsProvider.sign(sigResourceName, bodyBase64Bytes);
    String sha = TsrctCommonOps.sha256Digest(bodyBase64Bytes);

    String cid = TsrctCommonOps.getNowAsKeyIdDateFormat();

    Map<String, dynamic> synHeader = {
      "alg": "RS256",
      "cls": "org",
      "dom": dom,
      "its": TsrctCommonOps.getNowAsTdocDateFormat(),
      "len": jwksBodyBase64.length,
      "src": uid,
      "uid": "$uid.syn",
      "sig": sig,
      "slf": sig,
      "sha": sha,
      "typ": "syn",
      "cid": "$uid.$cid",
      "seq": 0,
      "dsc": "tsrct://org/syn/$dom",
      "nce": TsrctCommonOps.getNonce(),
    };

    TsrctDoc synTdoc = TsrctDoc.init(synHeader, jwksBodyBase64);
    Uint8List signable = synTdoc.generateSignableBytes();

    String signature = await keyActionsProvider.sign(sigResourceName, signable);
    synTdoc.hbsBase64 = signature;
    return synTdoc;
  }

  Future<ApiResponse> sendSynData(TsrctDoc synTdoc) async {
    String payload = synTdoc.generateRawTdoc();
    print(">> >> syn payload: \n$payload");

    ApiResponse ackResponse = await tsrctApi.postTdoc(payload);
    return ackResponse;
  }

  Future<TsrctDoc?> processAckTdoc(
    ArgResults argResults,
    String jwksBodyBase64,
    TsrctDoc synTdoc,
    String ackTdocString,
  ) async {
    String uid = argResults["uid"];
    // store ack locally
    Directory tsrctDir = await tsrctDirectory;

    File ackFile = await File("${tsrctDir.path}/${uid}.ack.tdoc").writeAsString(
        ackTdocString,
        encoding: utf8,
        flush: true,
        mode: FileMode.writeOnly);

    // validate tdoc for correctness
    TsrctDoc ackTdoc = TsrctDoc.parse(ackTdocString);
    Map<String, dynamic> ackBodyJson = parseBase64ToJson(ackTdoc.bodyBase64);
    print(">> >> ack body: \n$ackBodyJson");

    // todo: validate ack tdoc received
    // if invalid, return null
    // this will not work right now since domain key init has not occured
    // ApiResponse ackKeyResponse = await tsrctApi.getTdocByUid(ackTdoc.header["key"]);
    // TsrctCommonOps.validateTdoc(ackTdoc, ;

    return ackTdoc;
  }

  /// build the registration tdoc that will be sent in the registration request
  Future<TsrctDoc> _buildRegTdoc(
    ArgResults argResults,
    KeyActionsProvider keyActionsProvider,
    TsrctDoc ack,
  ) async {
    Map<String, dynamic> ackHeader = ack.header;

    String sigResourceName = argResults["sig-key-resource"];
    String keySetId = argResults["key-set-id"];
    String uid = argResults["uid"];
    String dom = argResults["dom"];

    Map<String, dynamic> ackJsonBody = parseBase64ToJson(ack.bodyBase64);
    String dns = ackJsonBody["dns"]["val"];

    List<dynamic> refArray = [
      {
        "uid": ack.header["uid"],
        "sha": ack.header["sha"],
        "sig": ack.header["sig"],
        "tds": ack.hbsBase64,
      },
    ];

    Map<String, dynamic> regBody = {
      "dom": dom,
      "uid": uid,
      "key": "$uid/$keySetId",
      "dns": dns,
    };

    String regBodyBase64 = convertJsonToBase64(regBody);
    Uint8List bodyBase64Bytes = Uint8List.fromList(utf8.encode(regBodyBase64));
    String sig =
        await keyActionsProvider.sign(sigResourceName, bodyBase64Bytes);
    String sha = TsrctCommonOps.sha256Digest(bodyBase64Bytes);

    Map<String, dynamic> regHeader = {
      "alg": "RS256",
      "cls": "org",
      "typ": "reg",
      "dom": dom,
      "its": TsrctCommonOps.getNowAsTdocDateFormat(),
      "key": "$uid.$keySetId",
      "len": regBodyBase64.length,
      "src": uid,
      "uid": uid,
      "sig": sig,
      "sha": sha,
      "cid": ackHeader["cid"],
      "seq": 2,
      "ref": refArray,
      "dsc": "tsrct://org/reg/$uid",
      "nce": TsrctCommonOps.getNonce(),
    };

    TsrctDoc regTsrctDoc = TsrctDoc.init(regHeader, regBodyBase64);

    Uint8List signable = regTsrctDoc.generateSignableBytes();
    String signature = await keyActionsProvider.sign(sigResourceName, signable);

    regTsrctDoc.hbsBase64 = signature;

    return regTsrctDoc;
  }

  /// build the tdoc that will be used for the key registration
  /// in the reg payload
  Future<TsrctDoc> _buildRegKeyTdoc(
    ArgResults argResults,
    KeyActionsProvider keyActionsProvider,
    String jwksBodyBase64,
    TsrctDoc ack,
    TsrctDoc reg,
  ) async {
    Map<String, dynamic> ackHeader = ack.header;

    String sigResourceName = argResults["sig-key-resource"];
    String keySetId = argResults["key-set-id"];
    String uid = argResults["uid"];

    List<dynamic> refArray = [
      {
        "uid": reg.header["uid"],
        "sha": reg.header["sha"],
        "sig": reg.header["sig"],
        "tds": reg.hbsBase64,
      },
    ];

    Map<String, dynamic> jwksHeader = {
      "cls": "key",
      "typ": "reg",
      "key": "$uid.$keySetId",
      "src": uid,
      "uid": "$uid.$keySetId",
      "cid": ackHeader["cid"],
      "seq": 3,
      "ref": refArray,
      "dsc": "tsrct://org/reg/key",
    };

    TsrctDoc keyTdoc =
      await TsrctCommonOps.buildSignedTsrctDoc(
          jwksHeader,
          true,
          jwksBodyBase64,
          sigResourceName,
          keyActionsProvider,
      );

    return keyTdoc;
  }
}
