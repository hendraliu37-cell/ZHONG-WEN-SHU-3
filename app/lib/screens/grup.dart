import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/room.dart';
import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';
import '../widgets/tutor_text.dart';

/// Realtime study rooms (Grup / M3). Three states: signed-out empty state,
/// the room list (with create + join), and an open room (live chat + presence).
class GrupScreen extends StatefulWidget {
  final AppController controller;
  final bool desktop;
  const GrupScreen({
    super.key,
    required this.controller,
    required this.desktop,
  });

  @override
  State<GrupScreen> createState() => _GrupScreenState();
}

class _GrupScreenState extends State<GrupScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _msg = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _msg.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await action();
    if (mounted) setState(() => _busy = false);
    if (err != null) _toast(err);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (!c.signedIn) return const _GuestState();
    if (c.currentRoom != null) {
      return _RoomView(
        controller: c,
        msgCtl: _msg,
        onSend: () {
          final txt = _msg.text.trim();
          if (txt.isEmpty) return;
          c.setRoomInput(txt);
          c.sendRoom();
          _msg.clear();
        },
      );
    }
    return SingleChildScrollView(
      child: _RoomList(
        controller: c,
        nameCtl: _name,
        codeCtl: _code,
        busy: _busy,
        onCreate: () => _run(() async {
          final err = await c.createRoom(_name.text.trim());
          if (err == null) _name.clear();
          return err;
        }),
        onJoin: () => _run(() async {
          final err = await c.joinRoom(_code.text.trim());
          if (err == null) _code.clear();
          return err;
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Signed-out
// ---------------------------------------------------------------------------

class _GuestState extends StatelessWidget {
  const _GuestState();
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return SurfaceBox(
      child: Column(
        children: [
          Icon(ZwsIcons.users, size: 34, color: t.ink3),
          const SizedBox(height: 12),
          Text(
            'Masuk untuk pakai grup',
            style: ZwsFonts.sans(
              size: 16,
              weight: FontWeight.w800,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ruang belajar bareng (chat realtime + panggil Guru pakai @Guru) '
            'butuh akun. Masuk dulu dari tab Profil.',
            textAlign: TextAlign.center,
            style: ZwsFonts.sans(size: 12, color: t.ink2, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Room list + create/join
// ---------------------------------------------------------------------------

class _RoomList extends StatelessWidget {
  final AppController controller;
  final TextEditingController nameCtl;
  final TextEditingController codeCtl;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  const _RoomList({
    required this.controller,
    required this.nameCtl,
    required this.codeCtl,
    required this.busy,
    required this.onCreate,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // My rooms
        SurfaceBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionLabel('Ruang kamu'),
                  if (c.roomLoading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.ink3,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (c.myRooms.isEmpty)
                Text(
                  'Belum ada ruang. Buat ruang baru atau gabung pakai kode.',
                  style: ZwsFonts.sans(size: 12, color: t.ink3, height: 1.5),
                )
              else
                for (final r in c.myRooms) ...[
                  _RoomTile(room: r, onTap: () => c.openRoomById(r)),
                  const SizedBox(height: 9),
                ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Create
        SurfaceBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Buat ruang baru'),
              const SizedBox(height: 12),
              _Field(controller: nameCtl, hint: 'Nama ruang (cth. Kelas Pagi)'),
              const SizedBox(height: 10),
              InkButton(
                label: busy ? 'Membuat…' : 'Buat ruang',
                icon: ZwsIcons.users,
                onTap: onCreate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Join
        SurfaceBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Gabung pakai kode'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: codeCtl,
                      hint: 'cth. ZWS-7F3KQ',
                      mono: true,
                      caps: true,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Material(
                    color: t.seal,
                    borderRadius: BorderRadius.circular(11),
                    child: InkWell(
                      onTap: onJoin,
                      borderRadius: BorderRadius.circular(11),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Text(
                          'Gabung',
                          style: ZwsFonts.sans(
                            size: 13,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoomTile extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;
  const _RoomTile({required this.room, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: ZwsFonts.sans(
                      size: 14,
                      weight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Mono(room.code, size: 11, color: t.ink3),
                      Text(
                        '  ·  ${room.memberCount} anggota',
                        style: ZwsFonts.sans(size: 11, color: t.ink3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (room.levelTag.isNotEmpty) ...[
              Pill(room.levelTag),
              const SizedBox(width: 8),
            ],
            Icon(ZwsIcons.chevron, size: 18, color: t.ink3),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Open room
// ---------------------------------------------------------------------------

class _RoomView extends StatefulWidget {
  final AppController controller;
  final TextEditingController msgCtl;
  final VoidCallback onSend;
  const _RoomView({
    required this.controller,
    required this.msgCtl,
    required this.onSend,
  });

  @override
  State<_RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<_RoomView> {
  final _scrollCtrl = ScrollController();
  bool _showGuruSuggest = false;

  @override
  void initState() {
    super.initState();
    widget.msgCtl.addListener(_syncSuggest);
  }

  @override
  void didUpdateWidget(covariant _RoomView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.msgCtl != widget.msgCtl) {
      oldWidget.msgCtl.removeListener(_syncSuggest);
      widget.msgCtl.addListener(_syncSuggest);
      _syncSuggest();
    }
  }

  @override
  void dispose() {
    widget.msgCtl.removeListener(_syncSuggest);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _syncSuggest() {
    final v = widget.msgCtl.value;
    final rawCaret = v.selection.baseOffset;
    final caret = rawCaret < 0
        ? v.text.length
        : rawCaret.clamp(0, v.text.length).toInt();
    final before = v.text.substring(0, caret);
    final token = before.split(RegExp(r'\s')).last;
    final show = isGuruMentionPrefix(token);
    if (show != _showGuruSuggest && mounted) {
      setState(() => _showGuruSuggest = show);
    }
  }

  void _insertGuruMention() {
    final ctl = widget.msgCtl;
    final value = ctl.value;
    final rawCaret = value.selection.baseOffset;
    final caret = rawCaret < 0
        ? value.text.length
        : rawCaret.clamp(0, value.text.length).toInt();
    final before = value.text.substring(0, caret);
    final after = value.text.substring(caret);
    final start = before.lastIndexOf(RegExp(r'\s'));
    final tokenStart = start < 0 ? 0 : start + 1;
    final nextText = '${before.substring(0, tokenStart)}@Guru $after'
        .replaceAll('  ', ' ');
    final nextCaret = tokenStart + 6;
    ctl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: nextCaret.clamp(0, nextText.length).toInt(),
      ),
    );
    setState(() => _showGuruSuggest = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = widget.controller;
    final room = c.currentRoom!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        SurfaceBox(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Material(
                color: t.surface2,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: c.closeRoomChannel,
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(ZwsIcons.back, size: 20, color: t.ink2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: ZwsFonts.sans(
                        size: 16,
                        weight: FontWeight.w800,
                        color: t.ink,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: t.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${c.roomOnline} online',
                          style: ZwsFonts.sans(size: 11, color: t.ink2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: room.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Kode ${room.code} disalin')),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.line),
                  ),
                  child: Row(
                    children: [
                      Mono(
                        room.code,
                        size: 11,
                        weight: FontWeight.w700,
                        color: t.ink,
                      ),
                      const SizedBox(width: 6),
                      Icon(ZwsIcons.copy, size: 13, color: t.ink3),
                    ],
                  ),
                ),
              ),
              _RoomMenu(controller: c),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Messages — scrollable, fills remaining space
        Expanded(
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              if (c.roomMsgs.isEmpty && !c.roomLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Belum ada pesan. Sapa anggota lain, atau tanya Guru dengan '
                    'menulis @Guru di pesanmu.',
                    textAlign: TextAlign.center,
                    style: ZwsFonts.sans(size: 12, color: t.ink3, height: 1.5),
                  ),
                ),
              for (final m in c.roomMsgs) ...[
                _RoomBubble(controller: c, msg: m, mine: m.isMine(c.authUid)),
                const SizedBox(height: 10),
              ],
              if (c.roomGuruBusy) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: t.sealSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Guru sedang mengetik…',
                      style: ZwsFonts.sans(size: 12, color: t.seal),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Input — pinned at bottom
        if (_showGuruSuggest) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: t.sealSoft,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: _insertGuruMention,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(ZwsIcons.chat, size: 14, color: t.seal),
                      const SizedBox(width: 6),
                      Text(
                        '@Guru',
                        style: ZwsFonts.sans(
                          size: 13,
                          weight: FontWeight.w800,
                          color: t.seal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: t.line),
                ),
                child: TextField(
                  controller: widget.msgCtl,
                  style: ZwsFonts.sans(size: 14, color: t.ink),
                  onSubmitted: (_) => widget.onSend(),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    border: InputBorder.none,
                    hintText: 'Tulis pesan… (@ untuk pilih Guru)',
                    hintStyle: ZwsFonts.sans(size: 14, color: t.ink3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Material(
              color: t.seal,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                onTap: widget.onSend,
                borderRadius: BorderRadius.circular(13),
                child: const SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(ZwsIcons.send, size: 20, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoomMenu extends StatelessWidget {
  final AppController controller;
  const _RoomMenu({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final owner = controller.isRoomOwner;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 20, color: t.ink2),
      onSelected: (v) async {
        if (v == 'leave') {
          await controller.leaveCurrentRoom();
        } else if (v == 'delete') {
          final ok = await _confirm(
            context,
            'Bubarkan ruang ini? Semua pesan akan dihapus untuk semua anggota.',
          );
          if (ok) await controller.deleteCurrentRoom();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'leave', child: Text('Keluar ruang')),
        if (owner)
          const PopupMenuItem(value: 'delete', child: Text('Bubarkan ruang')),
      ],
    );
  }

  Future<bool> _confirm(BuildContext context, String msg) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bubarkan'),
          ),
        ],
      ),
    );
    return res ?? false;
  }
}

class _RoomBubble extends StatelessWidget {
  final AppController controller;
  final RoomMessage msg;
  final bool mine;
  const _RoomBubble({
    required this.controller,
    required this.msg,
    required this.mine,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final guru = msg.isGuru;
    final align = mine ? Alignment.centerRight : Alignment.centerLeft;
    final bg = mine ? t.ink : (guru ? t.sealSoft : t.surface);
    final fg = mine ? t.bg : t.ink;
    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 3),
                child: Text(
                  guru ? 'Guru' : msg.authorName,
                  style: ZwsFonts.sans(
                    size: 11,
                    weight: FontWeight.w700,
                    color: guru ? t.seal : t.ink2,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(mine ? 14 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 14),
                ),
                border: (!mine && !guru) ? Border.all(color: t.line) : null,
              ),
              child: guru
                  ? TutorText(
                      text: controller.displayTutorText(msg.body),
                      color: fg,
                      compact: true,
                    )
                  : SelectableText(
                      msg.body,
                      style: ZwsFonts.sans(size: 14, color: fg, height: 1.5),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool mono;
  final bool caps;
  const _Field({
    required this.controller,
    required this.hint,
    this.mono = false,
    this.caps = false,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: t.line),
      ),
      child: TextField(
        controller: controller,
        textCapitalization: caps
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        style: mono
            ? ZwsFonts.mono(size: 13, color: t.ink)
            : ZwsFonts.sans(size: 14, color: t.ink),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: mono
              ? ZwsFonts.mono(size: 13, color: t.ink3)
              : ZwsFonts.sans(size: 14, color: t.ink3),
        ),
      ),
    );
  }
}
