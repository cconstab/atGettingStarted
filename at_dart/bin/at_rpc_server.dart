// dart packages
import 'dart:convert';
import 'dart:io';

// atPlatform packages
import 'package:at_client/at_client.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_utils/at_logger.dart';

// External Packages
import 'package:args/args.dart';
import 'package:logging/logging.dart';

const JsonEncoder jsonPrettyPrinter = JsonEncoder.withIndent('    ');

Future<void> main(List<String> args) async {
  ArgParser parser = CLIBase.argsParser
    ..addOption('client-atsigns',
        abbr: 'o',
        mandatory: true,
        help:
            'Comma-separated list of atSigns we wish to allow to communicate with us');

  try {
    var parsed = parser.parse(args);
    Set<String> clientAtSigns =
        parsed['client-atsigns'].toString().split(',').toSet();

    CLIBase cliBase = await CLIBase.fromCommandLineArgs(args, parser: parser);
    MyRpcServer server = MyRpcServer(cliBase.atClient, clientAtSigns);

    await server.listenForRequests();
  } catch (e) {
    print(parser.usage);
    print(e);
    exit(1);
  }
}

class MyRpcServer implements AtRpcCallbacks {
  late final AtSignLogger logger;

  final AtClient atClient;
  final Set<String> clientAtSigns;

  MyRpcServer(this.atClient, this.clientAtSigns) {
    logger = AtSignLogger('MyRpcServer');
    logger.logger.level = Level.INFO;
  }

  Future<void> listenForRequests() async {
    logger.info('Listening for requests');

    AtRpc rpc = AtRpc(
        atClient: atClient,
        baseNameSpace: atClient.getPreferences()!.namespace!,
        domainNameSpace: 'time',
        callbacks: this,
        allowList: clientAtSigns);

    rpc.start();
  }

  @override
  Future<AtRpcResp> handleRequest(AtRpcReq request, String fromAtSign) async {
    logger.info(
        'Received request from $fromAtSign: ${jsonPrettyPrinter.convert(request.toJson())}');

    var response = AtRpcResp(
        reqId: request.reqId,
        respType: AtRpcRespType.success,
        payload: {'time': DateTime.now().toUtc().toIso8601String()});

    logger.info(
        'Sending response ${jsonPrettyPrinter.convert(response.toJson())}');

    return response;
  }

  @override
  Future<void> handleResponse(AtRpcResp response) async {
    // We aren't making any requests so we're not expecting any responses
    logger.warning(
        'Received unexpected response message ${jsonPrettyPrinter.convert(response.toJson())}');
  }
}
