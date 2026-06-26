import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';

class ProfilScreen extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const ProfilScreen({super.key, required this.controller, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // header
        _ProfileHeader(controller: c),
        const SizedBox(height: 14),
        // track
        SurfaceBox(
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Jalur belajar'),
              const SizedBox(height: 12),
              Row(
                children: [
                  _TrackBtn(controller: c, value: 'simplified', han: '简', label: 'Simplified'),
                  const SizedBox(width: 8),
                  _TrackBtn(controller: c, value: 'traditional', han: '繁', label: 'Traditional'),
                  const SizedBox(width: 8),
                  _TrackBtn(controller: c, value: 'both', han: '简繁', label: 'Keduanya'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // rapor
        SurfaceBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionLabel('Rapor berbobot'),
                  Mono('${c.raporTotal} / ${c.raporLetter}',
                      size: 13, weight: FontWeight.w800, color: t.seal),
                ],
              ),
              const SizedBox(height: 14),
              for (final r in c.rapor) ...[
                _RaporRow(name: r.name, weight: r.weight, score: r.score),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        // settings
        SurfaceBox(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.line)),
                ),
                child: const SectionLabel('Pengaturan'),
              ),
              _SettingRow(
                title: 'Mode tampilan',
                sub: _themeLabel(c.themeMode),
                trailing: _ThemeSeg(controller: c),
              ),
              _SettingRow(
                title: 'Tampilkan 注音 (zhuyin)',
                sub: 'Romanisasi Taiwan di kartu',
                trailing: _ZhuyinSwitch(controller: c),
              ),
              _SettingRow(
                title: 'Sumber suara',
                sub: 'Suara daratan & Taiwan',
                trailing: Mono('Otomatis', size: 12, color: t.ink3),
              ),
              _SettingRow(
                title: 'Bahasa antarmuka',
                sub: 'Indonesia',
                trailing: Mono('ID / EN', size: 12, color: t.ink3),
              ),
              if (!c.authEnabled)
                _SettingRow(
                  title: 'Atur ulang jalur belajar',
                  sub: 'Buka kembali layar onboarding',
                  bottomBorder: false,
                  trailing: Material(
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: c.resetOnboard,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: t.line),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        child: Text('Buka',
                            style: ZwsFonts.sans(
                                size: 13,
                                weight: FontWeight.w600,
                                color: t.seal)),
                      ),
                    ),
                  ),
                ),
              if (c.authEnabled)
                _SettingRow(
                  title: 'Keluar',
                  sub: c.profileHandle.isEmpty
                      ? 'Logout dari akun'
                      : 'Logout dari [ ${c.profileHandle} ]',
                  bottomBorder: false,
                  trailing: Material(
                    color: t.sealSoft,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: c.logout,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        child: Text('Logout',
                            style: ZwsFonts.sans(
                                size: 13,
                                weight: FontWeight.w700,
                                color: t.seal)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _themeLabel(String mode) => switch (mode) {
        'light' => 'Terang',
        'dark' => 'Gelap',
        _ => 'Ikut sistem',
      };
}

class _ProfileHeader extends StatelessWidget {
  final AppController controller;
  const _ProfileHeader({required this.controller});

  Future<void> _pickAvatar() async {
    const group = XTypeGroup(
        label: 'Gambar', extensions: ['png', 'jpg', 'jpeg', 'webp']);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'png';
    await controller.setAvatar(bytes, ext);
  }

  Future<void> _editUsername(BuildContext context) async {
    final t = ZwsTheme.of(context);
    final tec = TextEditingController(text: controller.profileHandle);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        String? err;
        bool busy = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            backgroundColor: t.surface,
            title: Text('Ubah username',
                style: ZwsFonts.sans(
                    size: 16, weight: FontWeight.w800, color: t.ink)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: t.line),
                  ),
                  child: TextField(
                    controller: tec,
                    autocorrect: false,
                    style: ZwsFonts.sans(size: 14, color: t.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 13),
                      border: InputBorder.none,
                      hintText: 'username baru',
                      hintStyle: ZwsFonts.sans(size: 14, color: t.ink3),
                    ),
                  ),
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(err!,
                      style: ZwsFonts.sans(
                          size: 12, color: t.seal, weight: FontWeight.w600)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: Text('Batal',
                    style: ZwsFonts.sans(size: 13, color: t.ink2)),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        setLocal(() => busy = true);
                        final e = await controller.changeUsername(tec.text);
                        if (e == null) {
                          if (ctx.mounted) Navigator.pop(ctx);
                        } else {
                          setLocal(() {
                            err = e;
                            busy = false;
                          });
                        }
                      },
                child: Text('Simpan',
                    style: ZwsFonts.sans(
                        size: 13, weight: FontWeight.w700, color: t.seal)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _avatar(ZwsTokens t) {
    final c = controller;
    Widget inner;
    if (c.avatarBusy) {
      inner = Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
        ),
      );
    } else if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          c.avatarUrl!,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Han('书', size: 34, color: Colors.white),
        ),
      );
    } else {
      inner = Han('书', size: 34, color: Colors.white);
    }
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.seal,
        borderRadius: BorderRadius.circular(16),
      ),
      child: inner,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final editable = c.authEnabled && c.signedIn;
    return SurfaceBox(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: (editable && !c.avatarBusy) ? _pickAvatar : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.rotate(angle: -0.07, child: _avatar(t)),
                if (editable)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: t.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.line),
                      ),
                      child: Icon(Icons.photo_camera_outlined,
                          size: 13, color: t.ink2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.profileName.isEmpty ? 'Murid' : c.profileName,
                    style: ZwsFonts.sans(
                        size: 22, weight: FontWeight.w800, color: t.ink)),
                Row(
                  children: [
                    Flexible(
                      child: Mono(
                        editable
                            ? '[ ${c.profileHandle} ] · ${c.profileId}'
                            : 'Mode tamu',
                        size: 13,
                        color: t.ink3,
                      ),
                    ),
                    if (editable) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _editUsername(context),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(Icons.edit_outlined,
                              size: 15, color: t.seal),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  editable
                      ? '中文加油！Teruskan belajarmu.'
                      : 'Mode tamu — masuk untuk menyimpan progres.',
                  style: ZwsFonts.sans(size: 12, color: t.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackBtn extends StatelessWidget {
  final AppController controller;
  final String value;
  final String han;
  final String label;
  const _TrackBtn(
      {required this.controller,
      required this.value,
      required this.han,
      required this.label});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final on = controller.track == value;
    return Expanded(
      child: InkWell(
        onTap: () => controller.setTrack(value),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
          decoration: BoxDecoration(
            color: on ? t.sealSoft : t.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: on ? t.seal : t.line),
          ),
          child: Column(
            children: [
              Han(han, size: 22, color: on ? t.seal : t.ink2),
              const SizedBox(height: 5),
              Text(label,
                  style: ZwsFonts.sans(
                      size: 11,
                      weight: FontWeight.w600,
                      color: on ? t.seal : t.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaporRow extends StatelessWidget {
  final String name;
  final String weight;
  final int score;
  const _RaporRow(
      {required this.name, required this.weight, required this.score});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final color = score >= 85 ? t.green : (score >= 75 ? t.gold : t.seal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(name,
                    style: ZwsFonts.sans(
                        size: 13, weight: FontWeight.w600, color: t.ink)),
                const SizedBox(width: 6),
                Text('· bobot $weight',
                    style: ZwsFonts.sans(size: 11, color: t.ink3)),
              ],
            ),
            Mono('$score', size: 13, weight: FontWeight.w700, color: t.ink),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 6,
            backgroundColor: t.line2,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final String sub;
  final Widget trailing;
  final bool bottomBorder;
  const _SettingRow({
    required this.title,
    required this.sub,
    required this.trailing,
    this.bottomBorder = true,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: bottomBorder
            ? Border(bottom: BorderSide(color: t.line))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: ZwsFonts.sans(
                        size: 14, weight: FontWeight.w600, color: t.ink)),
                Text(sub, style: ZwsFonts.sans(size: 11, color: t.ink3)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _ThemeSeg extends StatelessWidget {
  final AppController controller;
  const _ThemeSeg({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    Widget seg(String mode, String label) {
      final on = controller.themeMode == mode;
      return InkWell(
        onTap: () => controller.setTheme(mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: on ? t.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: ZwsFonts.sans(
                  size: 12,
                  weight: FontWeight.w700,
                  color: on ? t.ink : t.ink3)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('light', 'Terang'),
          seg('dark', 'Gelap'),
          seg('system', 'Sistem'),
        ],
      ),
    );
  }
}

class _ZhuyinSwitch extends StatelessWidget {
  final AppController controller;
  const _ZhuyinSwitch({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final on = controller.zhuyin;
    return InkWell(
      onTap: controller.toggleZhuyin,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 46,
        height: 27,
        decoration: BoxDecoration(
          color: on ? t.seal : t.line,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 21,
            height: 21,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
