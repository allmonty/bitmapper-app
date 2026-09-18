import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:win98_ui/win98_ui.dart';

import 'l10n/generated/app_localizations.dart';
import 'models/editor_model.dart';
import 'models/media_model.dart';
import 'models/presets_model.dart';
import 'screens/home_screen.dart';
import 'services/app_services.dart';
import 'services/filter_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(BitmapperApp(services: AppServices.production()));
}

class BitmapperApp extends StatelessWidget {
  const BitmapperApp({super.key, required this.services, this.locale});

  final AppServices services;

  /// Forces a locale (tests); the device locale is used otherwise.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider(create: (_) => EditorModel()),
        ChangeNotifierProvider(
          create: (_) => MediaModel(services.imageLoader, videoIO: services.videoIO),
        ),
        ChangeNotifierProvider(create: (_) => PresetsModel(services.presetRepository)..load()),
        ChangeNotifierProvider(
          create: (_) =>
              FilterController(runner: services.filterRunner, debounce: services.previewDebounce),
        ),
      ],
      child: WidgetsApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        color: const Win98ThemeData().desktop,
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, navigator) => Win98Theme(child: navigator!),
        pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
