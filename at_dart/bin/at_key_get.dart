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
  if (args.length < 2 || args.length > 2) {
    print('at_key <from atSign> <to atSign>');
    exit(-1);
  }
  String fromAtsign = args[0];
  String toAtsign = args[1];

  // Now on to the atPlatform startup
  AtSignLogger.root_level = 'SHOUT';

  String? homeDirectory = getHomeDirectory();
  // Namespace by convention is an atSign you own
  // prevents applications clashing!
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
    ..ttl = 30000;

  var key = AtKey()
    ..key = 'message'
    ..sharedBy = toAtsign
    ..sharedWith = fromAtsign
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

  // Wait for initial sync to complete
  stdout.write(chalk.brightBlue("Synching your data."));
  var mySynclistener = MySyncProgressListener();
  atClient.syncService.addProgressListener(mySynclistener);
  while (!mySynclistener.syncComplete) {
    await Future.delayed(Duration(milliseconds: 250));
    stdout.write(chalk.brightBlue('.'));
  }

  AtValue text = AtValue();
  bool found = false;
  try {
    text = await atClient.get(key);
    found = true;
  } catch (e) {
    print(e.toString());
    print(chalk.brightRed('Null'));
  }
  if (found) {
    stdout.writeln(text.toString());
    stdout.writeln(chalk.brightGreen(text.value));
  }
  exit(0);
}
