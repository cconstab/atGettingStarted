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

Future<void> main(List<String> args) async {
  if (args.length < 3 || args.length > 3) {
    print('at_notify_send <from atSign> <to atSign> <txt>');
    exit(-1);
  }
  String fromAtsign = args[0];
  String toAtsign = args[1];
  String text = args[2];

  // Now on to the atPlatform startup
  AtSignLogger.root_level = 'SHOUT';

  String? homeDirectory = getHomeDirectory();
  String nameSpace = 'colin';

  //onboarding preference builder can be used to set onboardingService parameters
  AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    ..hiveStoragePath = '$homeDirectory/.$nameSpace/$fromAtsign/storage'
    ..namespace = nameSpace
    ..downloadPath = '$homeDirectory/.$nameSpace/files'
    ..isLocalStoreRequired = true
    ..commitLogPath = '$homeDirectory/.$nameSpace/$fromAtsign/storage/commitLog'
    ..fetchOfflineNotifications = true
    ..atProtocolEmitted = Version(2, 0, 0);

  var metaData = Metadata()
    ..isPublic = false
    ..isEncrypted = true
    ..namespaceAware = true
    ..ttr = -1
    ..ttl = 30000;

  var key = AtKey()
    ..key = 'message'
    ..sharedBy = fromAtsign
    ..sharedWith = toAtsign
    ..namespace = nameSpace
    ..metadata = metaData;

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

  AtClient atClient = AtClientManager.getInstance().atClient;

  int a = 1;
  //Sending the same key results in the latest key being looked up
  
  // await atClient.put(key, text);
  // while (a < 4) {
  //   await atClient.put(key, a.toString());
  //   a++;
  // }
 
  // Using notifications we get all the updates

  await atClient.notificationService.notify(NotificationParams.forUpdate(key, value:text),
        waitForFinalDeliveryStatus: false, checkForFinalDeliveryStatus: false);
  
  while (a < 4) {
    await atClient.notificationService.notify(NotificationParams.forUpdate(key, value: a.toString()),
        waitForFinalDeliveryStatus: false, checkForFinalDeliveryStatus: false);
    a++;
  }

  await Future.delayed(Duration(seconds: 20));
  exit(0);
}
