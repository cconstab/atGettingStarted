// dart packages
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// atPlatform packages
import 'package:at_client/at_client.dart';
import 'package:at_cli_commons/at_cli_commons.dart';

// External Packages
import 'package:args/args.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';

const JsonEncoder jsonPrettyPrinter = JsonEncoder.withIndent('    ');

Future<void> main(List<String> args) async {
  ArgParser parser = CLIBase.argsParser
    ..addOption('server-atsign',
        abbr: 'o',
        mandatory: true,
        help:
        'The atSign to which we are sending requests');

  try {
    var parsed = parser.parse(args);
    String serverAtSign = parsed['server-atsign'];

    CLIBase cliBase = await CLIBase.fromCommandLineArgs(args, parser: parser);
    MyRpcClient client = MyRpcClient(cliBase.atClient, serverAtSign);

    AtRpcResp response = await client.sendRequest();
    print('Received response: ${jsonPrettyPrinter.convert(response.toJson())}');

    exit(0);
  } catch (e) {
    print(parser.usage);
    print(e);
    exit(1);
  }
}

class MyRpcClient implements AtRpcCallbacks {
  late final AtSignLogger logger;

  final AtClient atClient;
  final String serverAtSign;
  late final AtRpc rpc;

  MyRpcClient(this.atClient, this.serverAtSign) {
    logger = AtSignLogger('MyRpcClient');
    logger.logger.level = Level.INFO;

    rpc = AtRpc(
        atClient: atClient,
        baseNameSpace: atClient.getPreferences()!.namespace!,
        domainNameSpace: 'time',
        callbacks: this,
        allowList: {serverAtSign});

    rpc.start();
  }

  final Completer<AtRpcResp> completer = Completer<AtRpcResp>();

  Future<AtRpcResp> sendRequest() async {
    AtRpcReq req = AtRpcReq.create({'message':'What time is it there??'});
    await rpc.sendRequest(toAtSign: serverAtSign, request: req);

    return completer.future;
  }

  @override
  Future<void> handleResponse(AtRpcResp response) async {
    completer.complete(response);
  }

  @override
  Future<AtRpcResp> handleRequest(AtRpcReq request, String fromAtSign) async {
    // Not expecting any requests!
    logger.warning(
        'Received unexpected request from $fromAtSign: ${jsonPrettyPrinter.convert(request.toJson())}');
    return AtRpcResp.nack(request: request, message: 'Nope nope nope');
  }
}
