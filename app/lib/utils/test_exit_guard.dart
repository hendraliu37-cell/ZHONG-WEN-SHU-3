import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';

Future<void> closeSubWithTestGuard(
  BuildContext context,
  AppController controller,
) async {
  if (controller.sub == 'ujian_akhir') {
    await closeUjianAkhirWithGuard(context, controller);
    return;
  }
  if (!controller.hasActiveTestInProgress) {
    controller.closeSub();
    return;
  }
  final t = ZwsTheme.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: t.surface,
      title: Text(
        'Keluar dari tes?',
        style: ZwsFonts.sans(size: 17, weight: FontWeight.w800, color: t.ink),
      ),
      content: Text(
        'Progress tes akan disimpan ke riwayat, jadi bisa dilanjutkan lagi nanti.',
        style: ZwsFonts.sans(size: 13, color: t.ink2, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Batal', style: ZwsFonts.sans(size: 13, color: t.ink2)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Simpan & keluar',
            style: ZwsFonts.sans(
              size: 13,
              weight: FontWeight.w700,
              color: t.seal,
            ),
          ),
        ),
      ],
    ),
  );
  if (ok == true) {
    controller.abandonActiveTestToHistory();
    controller.closeSub();
  }
}

Future<void> closeUjianAkhirWithGuard(
  BuildContext context,
  AppController controller,
) async {
  if (!controller.ujianAkhirInProgress) {
    controller.closeSub();
    return;
  }
  final t = ZwsTheme.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: t.surface,
      title: Text(
        'Keluar dari ujian?',
        style: ZwsFonts.sans(size: 17, weight: FontWeight.w800, color: t.ink),
      ),
      content: Text(
        'Progress Ujian Akhir belum bisa dilanjutkan nanti. Nilai hanya disimpan kalau ujian selesai.',
        style: ZwsFonts.sans(size: 13, color: t.ink2, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Batal', style: ZwsFonts.sans(size: 13, color: t.ink2)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Keluar',
            style: ZwsFonts.sans(
              size: 13,
              weight: FontWeight.w700,
              color: t.seal,
            ),
          ),
        ),
      ],
    ),
  );
  if (ok == true) controller.closeSub();
}
