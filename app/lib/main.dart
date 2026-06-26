import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_shell.dart';
import 'config.dart';
import 'screens/auth.dart';
import 'screens/onboarding.dart';
import 'state/app_controller.dart';
import 'state/providers.dart';
import 'theme/tokens.dart';
import 'theme/zws_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  if (ZwsConfig.hasSupabase) {
    try {
      await Supabase.initialize(
        url: ZwsConfig.supabaseUrl,
        publishableKey: ZwsConfig.supabasePublishableKey,
      ).timeout(const Duration(seconds: 5));
      zwsSupabaseReady = true;
    } catch (_) {
      // Try once more without waiting
      try {
        await Supabase.initialize(
          url: ZwsConfig.supabaseUrl,
          publishableKey: ZwsConfig.supabasePublishableKey,
        );
        zwsSupabaseReady = true;
      } catch (_) {
        zwsSupabaseReady = false;
      }
    }
  }
  runApp(const ProviderScope(child: ZwsApp()));
}

class ZwsApp extends ConsumerWidget {
  const ZwsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final platform =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final tokens = resolveTokens(c.themeMode, platform);
        return MaterialApp(
          title: 'Zhongwen Shu',
          debugShowCheckedModeBanner: false,
          theme: zwsThemeData(tokens),
          home: ZwsTheme(
            tokens: tokens,
            child: _Root(controller: c),
          ),
        );
      },
    );
  }
}

class _Root extends StatelessWidget {
  final AppController controller;
  const _Root({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    if (!controller.ready) {
      return Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 30, height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2.5)),
                const SizedBox(height: 16),
                Text('Menyiapkan…', style: ZwsFonts.sans(size: 13, color: t.ink3)),
              ],
            ),
          ),
        ),
      );
    }
    if (controller.authEnabled && !controller.signedIn) {
      return Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(child: AuthScreen(controller: controller)),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: controller.onboarded
            ? AppShell(controller: controller)
            : OnboardingScreen(controller: controller),
      ),
    );
  }
}
