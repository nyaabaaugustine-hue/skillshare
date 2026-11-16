import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../features/auth/family_link.dart';
import 'premium_button.dart';

/// Shows the Parent / Guardian login that was just created for [credentials].
///
/// Shown once, right after a student registers: the family reads or copies the
/// credentials, hands them over, and the parent can sign in straight away —
/// no second signup and no "connect accounts" step.
Future<void> showGuardianCredentialsSheet(
  BuildContext context, {
  required GuardianCredentials credentials,
  required String studentName,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) => _GuardianCredentialsSheet(
    credentials: credentials,
    studentName: studentName,
  ),
);

class _GuardianCredentialsSheet extends StatelessWidget {
  const _GuardianCredentialsSheet({
    required this.credentials,
    required this.studentName,
  });

  final GuardianCredentials credentials;
  final String studentName;

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
  }

  @override
  Widget build(BuildContext context) {
    final creds = credentials;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: SkillBridgeColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: SkillBridgeColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: SkillBridgeColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Parent / Guardian login created',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SkillBridgeColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Already linked to $studentName — hand these to ${creds.name} '
              'and they can track progress right away.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SkillBridgeColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _CredentialCard(
              label: 'Login',
              value: creds.login,
              onCopy: () => _copy('login', creds.login),
            ),
            const SizedBox(height: 10),
            _CredentialCard(
              label: 'Password',
              value: creds.password,
              onCopy: () => _copy('password', creds.password),
            ),
            const SizedBox(height: 16),
            PremiumButton(
              label: 'I have saved them',
              onPressed: () => Navigator.of(context).pop(),
              height: 52,
            ),
            const SizedBox(height: 8),
            const Text(
              'You can reset the parent password later in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SkillBridgeColors.textMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CredentialCard extends StatelessWidget {
  const _CredentialCard({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: SkillBridgeColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SkillBridgeColors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: SkillBridgeColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(
                    color: SkillBridgeColors.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy $label',
            onPressed: onCopy,
            color: SkillBridgeColors.primary,
            icon: const Icon(Icons.copy_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
