import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';

/// Sign-in / sign-up gate, shown when a backend is configured and no user is
/// signed in. Register also picks the learning track (so onboarding is skipped).
class AuthScreen extends StatefulWidget {
  final AppController controller;
  const AuthScreen({super.key, required this.controller});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _register = false;
  bool _hidePassword = true;
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _handle = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _handle.dispose();
    super.dispose();
  }

  void _switch(bool register) {
    setState(() {
      _register = register;
      _localError = null;
    });
    widget.controller.clearAuthError();
  }

  String? _validate() {
    final email = _email.text.trim();
    if (!email.contains('@') || email.length < 5) return 'Email tidak valid.';
    if (_pass.text.length < 6) return 'Kata sandi minimal 6 karakter.';
    if (_register) {
      final h = _handle.text.trim().toLowerCase();
      if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(h)) {
        return 'Username: 3-20 karakter, huruf kecil/angka/garis bawah.';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final v = _validate();
    if (v != null) {
      setState(() => _localError = v);
      return;
    }
    setState(() => _localError = null);
    final c = widget.controller;
    if (_register) {
      await c.register(
        email: _email.text,
        password: _pass.text,
        handle: _handle.text,
      );
    } else {
      await c.login(email: _email.text, password: _pass.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = widget.controller;
    final error = _localError ?? c.authError;
    return Container(
      color: t.bg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: SealMark(size: 58, fontSize: 35, radius: 15),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Han('中文书', size: 28, color: t.ink, letterSpacing: 1.6),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _register ? 'Buat akun baru' : 'Masuk ke akunmu',
                    style: ZwsFonts.sans(size: 14, color: t.ink2),
                  ),
                ),
                const SizedBox(height: 24),
                _Field(
                  controller: _email,
                  hint: 'Email',
                  icon: Icons.alternate_email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                if (_register) ...[
                  _Field(
                    controller: _handle,
                    hint: 'Username (cth. andi_88)',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 10),
                ],
                _Field(
                  controller: _pass,
                  hint: 'Kata sandi',
                  icon: Icons.lock_outline,
                  obscure: _hidePassword,
                  suffixIcon: IconButton(
                    tooltip: _hidePassword
                        ? 'Tampilkan kata sandi'
                        : 'Sembunyikan kata sandi',
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 19,
                      color: t.ink3,
                    ),
                    onPressed: () {
                      setState(() => _hidePassword = !_hidePassword);
                    },
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_register) ...[
                  const SizedBox(height: 16),
                  const SectionLabel('Jalur belajar'),
                  const SizedBox(height: 10),
                  _TrackPicker(controller: c),
                ],
                if (error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: t.sealSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      error,
                      style: ZwsFonts.sans(
                        size: 12,
                        color: t.seal,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: t.ink,
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      onTap: c.authBusy ? null : _submit,
                      borderRadius: BorderRadius.circular(13),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Center(
                          child: c.authBusy
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: t.bg,
                                  ),
                                )
                              : Text(
                                  _register ? 'Daftar' : 'Masuk',
                                  style: ZwsFonts.sans(
                                    size: 15,
                                    weight: FontWeight.w700,
                                    color: t.bg,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: InkWell(
                    onTap: c.authBusy ? null : () => _switch(!_register),
                    child: RichText(
                      text: TextSpan(
                        style: ZwsFonts.sans(size: 13, color: t.ink2),
                        children: [
                          TextSpan(
                            text: _register
                                ? 'Sudah punya akun? '
                                : 'Belum punya akun? ',
                          ),
                          TextSpan(
                            text: _register ? 'Masuk' : 'Daftar',
                            style: ZwsFonts.sans(
                              size: 13,
                              color: t.seal,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: t.line),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        autocorrect: false,
        enableSuggestions: false,
        style: ZwsFonts.sans(size: 14, color: t.ink),
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: Icon(icon, size: 19, color: t.ink3),
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 15,
          ),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: ZwsFonts.sans(size: 14, color: t.ink3),
        ),
      ),
    );
  }
}

class _TrackPicker extends StatelessWidget {
  final AppController controller;
  const _TrackPicker({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    Widget opt(String value, String han, String label) {
      final on = controller.track == value;
      return Expanded(
        child: InkWell(
          onTap: () => controller.setTrack(value),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: on ? t.sealSoft : t.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? t.seal : t.line),
            ),
            child: Column(
              children: [
                Han(han, size: 20, color: on ? t.seal : t.ink2),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: ZwsFonts.sans(
                    size: 10,
                    weight: FontWeight.w600,
                    color: on ? t.seal : t.ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        opt('simplified', '简', 'Daratan'),
        const SizedBox(width: 8),
        opt('traditional', '繁', 'Taiwan'),
        const SizedBox(width: 8),
        opt('both', '简繁', 'Keduanya'),
      ],
    );
  }
}
