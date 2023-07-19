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
    print('at_key <from atSign> <to atSign> <txt>');
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
    ..isLocalStoreRequired = true
    ..commitLogPath = '$homeDirectory/.$nameSpace/$fromAtsign/storage/commitLog'
    ..fetchOfflineNotifications = true
    ..atProtocolEmitted = Version(2, 0, 0);

  var metaData = Metadata()
    ..isPublic = false
    ..isEncrypted = true
    ..namespaceAware = true
    ..ttr = -1
    ..ttl = 60000;

  var key = AtKey()
    ..key = 'message'
    ..sharedBy = fromAtsign
    ..sharedWith = toAtsign
    ..namespace = nameSpace
    ..metadata = metaData;

  AtOnboardingService onboardingService =
      AtOnboardingServiceImpl(fromAtsign, atOnboardingConfig);
  bool onboarded = false;
  Duration retryDuration = Duration(seconds: 3);
  while (!onboarded) {
    try {
      stdout.write(chalk.brightBlue(
          '\r\x1b[KConnecting as${chalk.brightYellow(' $fromAtsign ')}${chalk.brightBlue(' : ')}'));
      await Future.delayed(Duration(
          milliseconds:
              1000)); // Pause just long enough for the retry to be visible
      onboarded = await onboardingService.authenticate();
    } catch (exception) {
      stdout.write(chalk.brightRed(
          '$exception. Will retry in ${retryDuration.inSeconds} seconds'));
    }
    if (!onboarded) {
      await Future.delayed(retryDuration);
    }
  }
  stdout.writeln(chalk.brightGreen('Connected'));

  AtClient atClient = AtClientManager.getInstance().atClient;

  // Wait for initial sync to complete
  stdout.write(chalk.brightBlue("Synching your data."));
  var mySynclistener = MySyncProgressListener();
  atClient.syncService.addProgressListener(mySynclistener);
  while (!mySynclistener.syncComplete) {
    await Future.delayed(Duration(milliseconds: 250));
    stdout.write(chalk.brightBlue('.'));
  }

  print('\r\n ${key.toString()}   :  $text');
  //await atClient.delete(key);
       await atClient.put(key, text);

   //Using atkeys we get the latest value
  // int a = 1;
  // while (a < 20) {
  //  await atClient.put(key, a.toString());
  //   a++;
  // }  
    await Future.delayed(Duration(seconds: 10));
   exit(0);
}
