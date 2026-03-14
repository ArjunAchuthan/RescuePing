import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../services/app_state.dart';
import 'home_screen.dart';
import 'rescuer_home_screen.dart';

/// Rich onboarding screen — collects emergency profile info.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    this.isEditing = false,
    this.role,
  });

  /// When true, we came from settings — show a back button.
  final bool isEditing;

  /// Role selected from RoleSelectionScreen (null when editing).
  final UserRole? role;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nicknameController = TextEditingController();
  final _medicalController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  String _bloodGroup = '';
  int _peopleCount = 1;
  late UserRole _role;

  static const _bloodGroups = [
    '',
    'A+',
    'A−',
    'B+',
    'B−',
    'AB+',
    'AB−',
    'O+',
    'O−',
  ];

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppState>().profile;
    if (profile != null) {
      _nicknameController.text = profile.nickname;
      _medicalController.text = profile.medicalNotes;
      _contactNameController.text = profile.emergencyContactName;
      _contactPhoneController.text = profile.emergencyContactPhone;
      _bloodGroup = profile.bloodGroup;
      _peopleCount = profile.peopleCount;
      _role = profile.role;
    } else {
      final nick = context.read<AppState>().nickname;
      if (nick != null) _nicknameController.text = nick;
      _role = widget.role ?? UserRole.needHelp;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _medicalController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  bool get _isRescuer => _role == UserRole.rescuer;

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a nickname')),
      );
      return;
    }

    final profile = UserProfile(
      nickname: nickname,
      role: _role,
      bloodGroup: _isRescuer ? '' : _bloodGroup,
      medicalNotes: _isRescuer ? '' : _medicalController.text.trim(),
      emergencyContactName:
          _isRescuer ? '' : _contactNameController.text.trim(),
      emergencyContactPhone:
          _isRescuer ? '' : _contactPhoneController.text.trim(),
      peopleCount: _isRescuer ? 1 : _peopleCount,
    );

    await context.read<AppState>().saveProfile(profile);

    if (!mounted) return;

    if (widget.isEditing) {
      Navigator.of(context).pop();
    } else {
      // Route to the correct home based on role.
      final Widget home = _isRescuer
          ? const RescuerHomeScreen()
          : const HomeScreen();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => home),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Profile' : 'Set Up Profile'),
        automaticallyImplyLeading: widget.isEditing,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── Header ───────────────────────────────────
              if (!widget.isEditing) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (_isRescuer
                                ? const Color(0xFF1565C0)
                                : const Color(0xFFE65100))
                            .withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _isRescuer ? Icons.shield : Icons.sos,
                        size: 48,
                        color: _isRescuer
                            ? const Color(0xFF2196F3)
                            : scheme.error,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRescuer
                            ? 'Rescuer Profile'
                            : 'Emergency Profile',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isRescuer
                            ? 'Set up your rescuer identity for the mesh network.'
                            : 'This info is sent with your SOS alerts to help rescuers.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ─── Nickname ────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Identity',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nicknameController,
                        autofocus: !widget.isEditing,
                        decoration: InputDecoration(
                          labelText: 'Nickname *',
                          hintText: _isRescuer
                              ? 'e.g. Rescue Team Alpha'
                              : 'e.g. Alex',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Trapped person-only fields ─────────────────
              if (!_isRescuer) ...[
                const SizedBox(height: 12),

                // Blood group & people count
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Basic Info',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _bloodGroup,
                          decoration: InputDecoration(
                            labelText: 'Blood Group (Optional)',
                            hintText: 'e.g. O+, A-',
                            prefixIcon: const Icon(Icons.water_drop),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          ),
                          items: _bloodGroups.map((g) {
                            return DropdownMenuItem(
                              value: g,
                              child: Text(g.isEmpty ? 'Not specified' : g),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _bloodGroup = v ?? ''),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.people, size: 20),
                            const SizedBox(width: 8),
                            const Text('People with you:'),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _peopleCount > 1
                                  ? () => setState(() => _peopleCount--)
                                  : null,
                            ),
                            Text(
                              '$_peopleCount',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () =>
                                  setState(() => _peopleCount++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Medical info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.medical_information,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Medical Info (optional)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _medicalController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Important Medical Notes (Optional)',
                            hintText: 'e.g. Allergies, conditions, medications...',
                            prefixIcon: const Icon(Icons.medical_services_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Emergency contact
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.contact_phone,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Emergency Contact (optional)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contactNameController,
                          decoration: InputDecoration(
                            labelText: 'Emergency Contact Name (Optional)',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contactPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Emergency Contact Phone (Optional)',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _save,
                icon: Icon(
                  widget.isEditing ? Icons.save : Icons.arrow_forward,
                ),
                label: Text(
                  widget.isEditing ? 'Save Changes' : 'Save & Continue',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              if (!widget.isEditing)
                Text(
                  _isRescuer
                      ? 'Your nickname is visible to other mesh devices.'
                      : 'Your data stays on your device. It is only shared over the mesh when you send an SOS.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
