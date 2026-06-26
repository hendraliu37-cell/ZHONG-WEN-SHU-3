import 'package:flutter/material.dart';

import 'state/app_controller.dart';
import 'theme/tokens.dart';
import 'theme/zws_theme.dart';
import 'widgets/common.dart';
import 'widgets/ico.dart';

import 'screens/beranda.dart';
import 'screens/belajar.dart';
import 'screens/chat.dart';
import 'screens/translate.dart';
import 'screens/profil.dart';

import 'overlays/deck_detail.dart';
import 'overlays/test_picker.dart';
import 'overlays/review.dart';
import 'overlays/quiz_mc.dart';
import 'overlays/spell.dart';
import 'overlays/games_hub.dart';
import 'overlays/tone_game.dart';
import 'overlays/match_game.dart';
import 'overlays/listen_game.dart';
import 'overlays/speed_game.dart';
import 'overlays/write_card.dart';
import 'overlays/leaderboard.dart';
import 'overlays/ujian_akhir.dart';

const _tabs = ['beranda', 'belajar', 'chat', 'translate', 'profil'];

class AppShell extends StatelessWidget {
  final AppController controller;
  const AppShell({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (controller.sub != null) {
            controller.closeSub();
          } else if (controller.tab != 'beranda') {
            controller.go('beranda');
          }
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 720;
        return Stack(
          children: [
            // Base layout — Positioned.fill gives it tight (bounded) height so
            // the inner Column's Expanded is valid.
            Positioned.fill(
              child: desktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DesktopRail(controller: controller),
                        Expanded(
                            child: _MainColumn(
                                controller: controller, desktop: true)),
                      ],
                    )
                  : _MainColumn(controller: controller, desktop: false),
            ),
            // Overlays
            ..._overlays(desktop),
          ],
        );
      },
    ),
    ); // PopScope
  }

  List<Widget> _overlays(bool desktop) {
    final c = controller;
    final widgets = <Widget>[];
    Widget? sub;
    switch (c.sub) {
      case 'deck':
        sub = DeckDetailOverlay(controller: c, desktop: desktop);
        break;
      case 'testpick':
        sub = TestPickerOverlay(controller: c, desktop: desktop);
        break;
      case 'review':
        sub = ReviewOverlay(controller: c, desktop: desktop);
        break;
      case 'quiz':
        sub = McQuizOverlay(controller: c, desktop: desktop);
        break;
      case 'spell':
        sub = SpellOverlay(controller: c, desktop: desktop);
        break;
      case 'games':
        sub = GamesHubOverlay(controller: c, desktop: desktop);
        break;
      case 'tone':
        sub = ToneGameOverlay(controller: c, desktop: desktop);
        break;
      case 'match':
        sub = MatchGameOverlay(controller: c, desktop: desktop);
        break;
      case 'listen':
        sub = ListenGameOverlay(controller: c, desktop: desktop);
        break;
      case 'speed':
        sub = SpeedGameOverlay(controller: c, desktop: desktop);
        break;
      case 'write':
        sub = WriteCardOverlay(controller: c, desktop: desktop);
        break;
      case 'ujian_akhir':
        sub = UjianAkhirOverlay(controller: c);
        break;
    }
    if (sub != null) widgets.add(Positioned.fill(child: sub));
    if (c.leaderOpen) {
      widgets.add(Positioned.fill(
          child: LeaderboardOverlay(controller: c, desktop: desktop)));
    }
    return widgets;
  }
}

// ===========================================================================
// DESKTOP RAIL
// ===========================================================================

class _DesktopRail extends StatelessWidget {
  final AppController controller;
  const _DesktopRail({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Container(
      width: 236,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(right: BorderSide(color: t.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 22),
            child: Row(
              children: [
                const SealMark(),
                const SizedBox(width: 11),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Han('中文书', size: 19, color: t.ink, letterSpacing: 0.8),
                      Text('ZHONGWEN SHU',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZwsFonts.sans(
                              size: 9,
                              weight: FontWeight.w600,
                              color: t.ink3,
                              letterSpacing: 2.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final name in _tabs)
            _RailItem(controller: controller, name: name),
          const Spacer(),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.line))),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.sealSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Han('安', size: 13, color: t.seal, weight: FontWeight.w700),
                ),
                const SizedBox(width: 9),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(controller.profileName,
                        style: ZwsFonts.sans(
                            size: 12, weight: FontWeight.w700, color: t.ink)),
                    Mono(controller.profileId, size: 10, color: t.ink3),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final AppController controller;
  final String name;
  const _RailItem({required this.controller, required this.name});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final on = controller.tab == name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: on ? t.sealSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: () => controller.go(name),
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                Icon(_iconFor(name), size: 22, color: on ? t.seal : t.ink2),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(_labelFor(name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZwsFonts.sans(
                          size: 14,
                          weight: on ? FontWeight.w700 : FontWeight.w600,
                          color: on ? t.seal : t.ink2)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// MAIN COLUMN (app bar + content + mobile nav)
// ===========================================================================

class _MainColumn extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const _MainColumn({required this.controller, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final isChat = controller.tab == 'chat';
    return Container(
      color: t.bg,
      child: Column(
        children: [
          _AppBar(controller: controller, desktop: desktop),
          Expanded(
            child: isChat
                ? Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: desktop ? 26 : 16, vertical: desktop ? 22 : 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: desktop ? 860 : double.infinity),
                        child: _activeScreen(),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: desktop ? 26 : 16,
                          vertical: desktop ? 22 : 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: desktop ? 860 : double.infinity),
                          child: _activeScreen(),
                        ),
                      ),
                    ),
                  ),
          ),
          if (!desktop) _MobileNav(controller: controller),
        ],
      ),
    );
  }

  Widget _activeScreen() {
    switch (controller.tab) {
      case 'belajar':
        return BelajarScreen(controller: controller, desktop: desktop);
      case 'chat':
        return ChatScreen(controller: controller, desktop: desktop);
      case 'translate':
        return TranslateScreen(controller: controller, desktop: desktop);
      case 'profil':
        return ProfilScreen(controller: controller, desktop: desktop);
      case 'beranda':
      default:
        return BerandaScreen(controller: controller, desktop: desktop);
    }
  }
}

class _AppBar extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const _AppBar({required this.controller, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final beranda = controller.tab == 'beranda';
    final (title, sub) = _titleFor(controller.tab);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: desktop ? 26 : 16, vertical: desktop ? 18 : 14),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          if (!desktop) ...[
            const SealMark(size: 32, fontSize: 20, radius: 9),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: beranda
                      ? ZwsFonts.han(
                          size: 24, weight: FontWeight.w700, color: t.ink)
                      : ZwsFonts.sans(
                          size: 16, weight: FontWeight.w800, color: t.ink),
                ),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZwsFonts.sans(size: 11, color: t.ink3)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: t.surface2,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: t.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: t.seal, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Mono('${controller.streak}',
                    size: 12, weight: FontWeight.w700, color: t.ink),
                const SizedBox(width: 4),
                Text('hari', style: ZwsFonts.sans(size: 11, color: t.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, String) _titleFor(String tab) {
    if (tab == 'beranda') {
      final hr = DateTime.now().hour;
      String han, id;
      if (hr >= 5 && hr < 11) {
        han = '早安';
        id = 'Selamat pagi, ${controller.profileName}';
      } else if (hr >= 11 && hr < 15) {
        han = '午安';
        id = 'Selamat siang, ${controller.profileName}';
      } else if (hr >= 15 && hr < 18) {
        han = '下午好';
        id = 'Selamat sore, ${controller.profileName}';
      } else {
        han = '晚上好';
        id = 'Selamat malam, ${controller.profileName}';
      }
      return (han, id);
    }
    const map = {
      'belajar': ('Belajar', 'Flashcard · tes · games'),
      'chat': ('Chat', 'Guru AI & grup belajar'),
      'translate': ('Translate', 'Terjemah · suara · foto'),
      'profil': ('Profil', 'Akun & rapor'),
    };
    return map[tab] ?? ('Beranda', '');
  }
}

class _MobileNav extends StatelessWidget {
  final AppController controller;
  const _MobileNav({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          for (final name in _tabs)
            Expanded(child: _NavButton(controller: controller, name: name)),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final AppController controller;
  final String name;
  const _NavButton({required this.controller, required this.name});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final on = controller.tab == name;
    return InkWell(
      onTap: () => controller.go(name),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(name), size: 22, color: on ? t.seal : t.ink3),
            const SizedBox(height: 4),
            Text(_labelFor(name),
                style: ZwsFonts.sans(
                    size: 10,
                    weight: on ? FontWeight.w700 : FontWeight.w500,
                    color: on ? t.seal : t.ink3)),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String name) => switch (name) {
      'beranda' => ZwsIcons.home,
      'belajar' => ZwsIcons.cards,
      'chat' => ZwsIcons.chat,
      'translate' => ZwsIcons.translate,
      'profil' => ZwsIcons.user,
      _ => ZwsIcons.home,
    };

String _labelFor(String name) => switch (name) {
      'beranda' => 'Beranda',
      'belajar' => 'Belajar',
      'chat' => 'Chat',
      'translate' => 'Translate',
      'profil' => 'Profil',
      _ => name,
    };
