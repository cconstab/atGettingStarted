// dart packages
import 'dart:io';

// atPlatform packages
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_utils/at_logger.dart';

// External Packages
import 'package:version/version.dart';
import 'package:chalkdart/chalk.dart';
import 'package:logging/src/level.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2 || args.length > 2) {
    print('at_notify_receive <atSign>');
    exit(-1);
  }
  String fromAtsign = args[0];

  // Now on to the atPlatform startup
  AtSignLogger.root_level = 'SHOUT';
  final AtSignLogger logger = AtSignLogger(' at_notify ');
  logger.hierarchicalLoggingEnabled = true;
  logger.logger.level = Level.SHOUT;

  String? homeDirectory = getHomeDirectory();
  // Namespace by convention is an atSign you own
  // prevents applications clashing!
  String nameSpace = 'colin';

  //onboarding preference builder can be used to set onboardingService parameters
  AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    ..hiveStoragePath = '$homeDirectory/.${nameSpace}get/$fromAtsign/storage'
    ..namespace = nameSpace
    ..fetchOfflineNotifications = false
    ..downloadPath = '$homeDirectory/.${nameSpace}get/files'
    ..isLocalStoreRequired = true
    ..commitLogPath = '$homeDirectory/.${nameSpace}get/$fromAtsign/storage/commitLog'
    ..fetchOfflineNotifications = false
    ..atProtocolEmitted = Version(2, 0, 0);

  AtOnboardingService onboardingService = AtOnboardingServiceImpl(fromAtsign, atOnboardingConfig);
  bool onboarded = false;
  Duration retryDuration = Duration(seconds: 3);
  while (!onboarded) {
    try {
      stdout.write(
          chalk.brightBlue('\r\x1b[KConnecting as${chalk.brightYellow(' $fromAtsign ')}${chalk.brightBlue(' : ')}'));
      await Future.delayed(Duration(milliseconds: 1000)); // Pause just long enough for the retry to be visible
      onboarded = await onboardingService.authenticate();
    } catch (exception) {
      stdout.write(chalk.brightRed('$exception. Will retry in ${retryDuration.inSeconds} seconds'));
    }
    if (!onboarded) {
      await Future.delayed(retryDuration);
    }
  }
  stdout.writeln(chalk.brightGreen('Connected'));
  pipePrint('$fromAtsign: ');

  AtClient atClient = AtClientManager.getInstance().atClient;
  
  atClient.notificationService.subscribe(regex: 'message.$nameSpace@', shouldDecrypt: true).listen(
      ((notification) async {
    String keyAtsign = notification.key;
    print(notification.key);
    keyAtsign = keyAtsign.replaceAll('${notification.to}:', '');
    keyAtsign = keyAtsign.replaceAll('.$nameSpace${notification.from}', '');
    if (keyAtsign == 'message') {
      logger.info('message received from ${notification.from} notification id : ${notification.id}');
      var talk = notification.value;
      // Terminal Control
      // '\r\x1b[K' is used to set the cursor back to the beginning of the line then deletes to the end of line
      //
      print(chalk.brightGreen.bold('\r\x1b[K${notification.from}: ') + chalk.brightGreen(talk));

      pipePrint('$fromAtsign: ');
    }
  }),
      onError: (e) => logger.severe('Notification Failed:$e'),
      onDone: () => logger.info('Notification listener stopped'));
}
