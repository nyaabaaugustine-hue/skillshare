import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../auth/auth_controller.dart';
import '../../shared/widgets/code_buddy.dart';
import '../../shared/widgets/entrance.dart';
import '../../shared/widgets/guardian_credentials_sheet.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/premium_button.dart';

/// Sign in / create account gate shown after every splash.
///
/// Authentication uses the shared account provider when configured; the
/// offline mock is limited to development and tests. "Continue as guest"
/// skips straight into the app for this session.
///
/// Signup is deliberately short: a name, an email and a password. The parent /
/// guardian login is an optional extra that lives behind one switch, because
/// it is only needed by families who want a second login.
class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({
    super.key,
    required this.onAuthenticated,
    required this.onGuest,
  });

  /// Called once a session exists (signed in, registered, or guest).
  final VoidCallback onAuthenticated;
  final VoidCallback onGuest;

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  final _guardianEmail = TextEditingController();

  bool _registerMode = false;
  bool _obscure = true;
  bool _parentLink = false;
  bool _awaitingOtp = false;
  UserRole _role = UserRole.student;

  bool get _isGuardian => _role == UserRole.guardian;

  void _selectRole(UserRole role) {
    if (role == _role) return;
    context.read<AuthController>().clearError();
    setState(() => _role = role);
  }

  @override
  void dispose() {
    _identifier.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    _guardianEmail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final auth = context.read<AuthController>();

    if (_awaitingOtp) {
      final ok = await auth.verifyEmail(
        email: auth.pendingVerificationEmail ?? _email.text.trim(),
        otp: _otp.text.trim(),
      );
      if (!mounted) return;
      if (ok) {
        widget.onAuthenticated();
      } else {
        form.validate();
      }
      return;
    }

    if (_registerMode && !_isGuardian) {
      // The switch is the opt-in: the address is only collected (and required)
      // when the family asked for a parent login and progress emails.
      final guardianEmail = _parentLink ? _guardianEmail.text.trim() : '';
      // No parent email: a plain, short registration.
      if (guardianEmail.isEmpty) {
        final ok = await auth.register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          role: UserRole.student,
        );
        if (!mounted) return;
        if (ok) {
          widget.onAuthenticated();
        } else if (auth.pendingVerificationEmail != null) {
          setState(() => _awaitingOtp = true);
        } else {
          form.validate();
        }
        return;
      }

      // A shared account creates a family group and invites the parent after
      // the student's email has been verified.
      final credentials = await auth.registerStudentWithGuardian(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        guardianEmail: guardianEmail,
      );
      if (!mounted) return;
      if (credentials == null) {
        if (auth.isAuthenticated) {
          widget.onAuthenticated();
        } else if (auth.pendingVerificationEmail != null) {
          setState(() => _awaitingOtp = true);
        } else {
          form.validate();
        }
        return;
      }
      await showGuardianCredentialsSheet(
        context,
        credentials: credentials,
        studentName: _name.text.trim(),
      );
      if (!mounted) return;
      widget.onAuthenticated();
      return;
    }

    final ok = _registerMode
        ? await auth.register(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            role: _role,
          )
        : await auth.login(
            identifier: _identifier.text.trim(),
            password: _password.text,
            role: _role,
          );
    if (!mounted) return;
    if (ok) {
      widget.onAuthenticated();
    } else if (auth.pendingVerificationEmail != null) {
      setState(() => _awaitingOtp = true);
    } else {
      form.validate();
    }
  }

  Future<void> _guest() async {
    final auth = context.read<AuthController>();
    await auth.continueAsGuest();
    if (!mounted) return;
    widget.onGuest();
  }

  void _switchMode() {
    context.read<AuthController>().clearError();
    setState(() {
      _registerMode = !_registerMode;
      _password.clear();
    });
  }

  String? _emailValidator(String? value) {
    final v = value?.trim() ?? '';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    if (!ok) return 'Enter a valid email address';
    return null;
  }

  String? _passwordValidator(String? value) {
    if ((value ?? '').length < 6) return 'At least 6 characters';
    return null;
  }

  String? _registrationPasswordValidator(String? value) {
    final password = value ?? '';
    if (password.length < 12 ||
        !RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      return 'Use 12+ characters with uppercase, lowercase, and a number';
    }
    return null;
  }

  String? _guardianEmailValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return "Enter your parent's email";
    return _emailValidator(v);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final error = auth.error;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1729), SkillBridgeColors.background],
            stops: [0.0, 0.55],
          ),
        ),
        child: Stack(
          children: [
            // Soft brand light behind the header, purely decorative.
            Positioned(
              top: -140,
              left: -80,
              right: -80,
              child: Container(
                height: 360,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      SkillBridgeColors.primary.withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _BrandRow(),
                        const SizedBox(height: 22),
                        Center(
                          child: Column(
                            children: [
                              const CodeBuddy(
                                size: 104,
                                mood: BuddyMood.thinking,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _registerMode
                                    ? (_isGuardian
                                          ? 'Create guardian account'
                                          : 'Create your account')
                                    : (_isGuardian
                                          ? 'Welcome, Parent / Guardian'
                                          : 'Welcome back, Student'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: SkillBridgeColors.textPrimary,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isGuardian
                                    ? "Follow your child's progress and stay "
                                          'connected.'
                                    : _registerMode
                                    ? 'Three details and you are in. Learn '
                                          'Python anywhere, even offline.'
                                    : 'Pick up your lessons right where you '
                                          'left off.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: SkillBridgeColors.textMuted,
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Entrance(
                          child: _RoleSelector(
                            role: _role,
                            onChanged: auth.busy || _awaitingOtp
                                ? null
                                : _selectRole,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ModeToggle(
                          registerMode: _registerMode,
                          onChanged: auth.busy || _awaitingOtp
                              ? null
                              : _switchMode,
                        ),
                        const SizedBox(height: 20),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_registerMode) ...[
                                TextFormField(
                                  controller: _name,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  autofocus: _registerMode,
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).nextFocus(),
                                  decoration: const InputDecoration(
                                    labelText: 'Full name',
                                    hintText: 'e.g. Ama Mensah',
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                    ),
                                  ),
                                  validator: (v) => (v?.trim().isEmpty ?? true)
                                      ? 'Enter your name'
                                      : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).nextFocus(),
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'you@example.com',
                                    prefixIcon: Icon(
                                      Icons.mail_outline_rounded,
                                    ),
                                  ),
                                  validator: _emailValidator,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    helperText:
                                        '12+ characters with uppercase, lowercase, and a number',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: _obscure
                                          ? 'Show password'
                                          : 'Hide password',
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: _registrationPasswordValidator,
                                ),
                                if (!_isGuardian) ...[
                                  const SizedBox(height: 14),
                                  _OptionalParentLink(
                                    expanded: _parentLink,
                                    enabled: !auth.busy,
                                    sharedAccount: auth.cloudAuthEnabled,
                                    email: _guardianEmail,
                                    validator: _guardianEmailValidator,
                                    onToggle: () => setState(
                                      () => _parentLink = !_parentLink,
                                    ),
                                  ),
                                ],
                              ] else
                                TextFormField(
                                  controller: _identifier,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofocus: !_registerMode,
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).nextFocus(),
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(
                                      Icons.mail_outline_rounded,
                                    ),
                                  ),
                                  validator: _emailValidator,
                                ),
                              if (!_registerMode) ...[
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  onFieldSubmitted: (_) =>
                                      auth.busy ? null : _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: _obscure
                                          ? 'Show password'
                                          : 'Hide password',
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: _passwordValidator,
                                ),
                              ],
                              if (_awaitingOtp) ...[
                                const SizedBox(height: 14),
                                Text(
                                  'Enter the verification code sent to ${auth.pendingVerificationEmail ?? _email.text.trim()}.',
                                  style: const TextStyle(
                                    color: SkillBridgeColors.textMuted,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _otp,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => auth.busy ? null : _submit(),
                                  decoration: const InputDecoration(
                                    labelText: 'Email verification code',
                                    prefixIcon: Icon(Icons.pin_outlined),
                                  ),
                                  validator: (value) => (value?.trim().isEmpty ?? true)
                                      ? 'Enter the code from your email'
                                      : null,
                                ),
                              ],
                              if (error != null) ...[
                                const SizedBox(height: 16),
                                _ErrorBanner(message: error),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        PremiumButton(
                          label: _awaitingOtp
                              ? 'Verify email'
                              : _registerMode
                              ? 'Create account'
                              : 'Sign in',
                          onPressed: auth.busy ? null : _submit,
                          height: 54,
                        ),
                        if (_awaitingOtp)
                          TextButton(
                            onPressed: auth.busy
                                ? null
                                : () => auth.resendVerificationCode(
                                    auth.pendingVerificationEmail ??
                                        _email.text.trim(),
                                  ),
                            child: const Text('Resend verification code'),
                          ),
                        if (auth.busy) ...[
                          const SizedBox(height: 14),
                          const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            ),
                          ),
                        ],
                        if (!_isGuardian) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(
                                  color: SkillBridgeColors.outline,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'or',
                                  style: TextStyle(
                                    color: SkillBridgeColors.textMuted
                                        .withValues(alpha: 0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(
                                  color: SkillBridgeColors.outline,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: auth.busy ? null : _guest,
                            icon: const Icon(Icons.explore_outlined, size: 20),
                            label: const Text('Continue as guest'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: SkillBridgeColors.surface
                                  .withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          _isGuardian
                              ? "Sign in with the parent login your child's "
                                    'account created — no separate signup '
                                    'needed.'
                              : auth.cloudAuthEnabled
                              ? 'Use the same account on your phone and in '
                                    'your browser.'
                              : 'Guest progress stays on this device. Create '
                                    'an account to use shared sign-in.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: SkillBridgeColors.textMuted,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small branded header row: transparent mark + wordmark, no white tile.
class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/icon/app_mark.png',
          width: 34,
          height: 34,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'SKILLBRIDGE',
              style: TextStyle(
                color: SkillBridgeColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.4,
                height: 1,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'ACADEMY',
              style: TextStyle(
                color: SkillBridgeColors.textMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.4,
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.role, required this.onChanged});

  final UserRole role;
  final ValueChanged<UserRole>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleCard(
            icon: Icons.school_rounded,
            title: 'Student',
            subtitle: 'Learn & code',
            colors: IconBadge.blue,
            selected: role == UserRole.student,
            onTap: onChanged == null
                ? null
                : () => onChanged!(UserRole.student),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RoleCard(
            icon: Icons.family_restroom_rounded,
            title: 'Parent / Guardian',
            subtitle: 'Track progress',
            colors: IconBadge.gold,
            selected: role == UserRole.guardian,
            onTap: onChanged == null
                ? null
                : () => onChanged!(UserRole.guardian),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = colors.last;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title login',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.14)
                : SkillBridgeColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : SkillBridgeColors.outline,
              width: selected ? 1.8 : 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 0.94,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Opacity(
                  opacity: selected ? 1 : 0.7,
                  child: IconBadge(
                    icon: icon,
                    colors: colors,
                    size: 46,
                    circle: true,
                    glow: selected,
                    iconColor: selected
                        ? (colors == IconBadge.gold
                              ? const Color(0xFF2A1D00)
                              : Colors.white)
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? SkillBridgeColors.textPrimary
                      : SkillBridgeColors.textMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SkillBridgeColors.textMuted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.registerMode, required this.onChanged});

  final bool registerMode;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SkillBridgeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SkillBridgeColors.outline),
      ),
      child: Row(
        children: [
          _Segment(
            label: 'Sign in',
            selected: !registerMode,
            onTap: onChanged == null || !registerMode ? null : onChanged!,
          ),
          _Segment(
            label: 'Create account',
            selected: registerMode,
            onTap: onChanged == null || registerMode ? null : onChanged!,
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? SkillBridgeColors.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? SkillBridgeColors.primary.withValues(alpha: 0.6)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? SkillBridgeColors.textPrimary
                  : SkillBridgeColors.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// One optional switch that reveals the single parent-contact field. Keeping
/// it collapsed means signup shows only the three fields every learner needs.
class _OptionalParentLink extends StatelessWidget {
  const _OptionalParentLink({
    required this.expanded,
    required this.enabled,
    required this.sharedAccount,
    required this.email,
    required this.validator,
    required this.onToggle,
  });

  final bool expanded;
  final bool enabled;
  final bool sharedAccount;
  final TextEditingController email;
  final FormFieldValidator<String> validator;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: SkillBridgeColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: expanded
              ? SkillBridgeColors.accent.withValues(alpha: 0.45)
              : SkillBridgeColors.outline,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onToggle : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  const IconBadge(
                    icon: Icons.family_restroom_rounded,
                    colors: IconBadge.gold,
                    size: 38,
                    circle: true,
                    glow: false,
                    iconColor: Color(0xFF2A1D00),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add a parent login',
                          style: TextStyle(
                            color: SkillBridgeColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sharedAccount
                              ? 'Optional — sends a family invitation after verification.'
                              : 'Optional — creates a local parent login and emails progress.',
                          style: const TextStyle(
                            color: SkillBridgeColors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: expanded,
                    onChanged: enabled ? (_) => onToggle() : null,
                    activeTrackColor: SkillBridgeColors.accent,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: "Parent's email",
                        helperText: sharedAccount
                            ? 'They receive the invitation at this email.'
                            : 'They sign in with it, and progress reports go here.',
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                      ),
                      validator: validator,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: SkillBridgeColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SkillBridgeColors.error.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: SkillBridgeColors.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: SkillBridgeColors.error,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
