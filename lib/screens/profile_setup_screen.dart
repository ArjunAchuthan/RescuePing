import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../services/app_state.dart';
import 'home_screen.dart';

/// Rich onboarding screen — collects emergency profile info.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.isEditing = false});

  /// When true, we came from settings — show a back button.
  final bool isEditing;

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
    } else {
      final nick = context.read<AppState>().nickname;
      if (nick != null) _nicknameController.text = nick;
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
      bloodGroup: _bloodGroup,
      medicalNotes: _medicalController.text.trim(),
      emergencyContactName: _contactNameController.text.trim(),
      emergencyContactPhone: _contactPhoneController.text.trim(),
      peopleCount: _peopleCount,
    );

    await context.read<AppState>().saveProfile(profile);

    if (!mounted) return;

    if (widget.isEditing) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Profile' : 'Rescue Mesh'),
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
                Icon(Icons.sos, size: 48, color: scheme.error),
                const SizedBox(height: 8),
                Text(
                  'Emergency Profile',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'This info is sent with your SOS alerts to help rescuers.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
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
                      Text(
                        'Basic Info',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nicknameController,
                        autofocus: !widget.isEditing,
                        decoration: const InputDecoration(
                          labelText: 'Nickname *',
                          hintText: 'e.g. Alex',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _bloodGroup,
                        decoration: const InputDecoration(
                          labelText: 'Blood Group',
                          prefixIcon: Icon(Icons.bloodtype),
                        ),
                        items: _bloodGroups.map((g) {
                          return DropdownMenuItem(
                            value: g,
                            child: Text(g.isEmpty ? 'Not specified' : g),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _bloodGroup = v ?? ''),
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
                            onPressed: () => setState(() => _peopleCount++),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── Medical ─────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Medical Info (optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _medicalController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Medical Notes',
                          hintText:
                              'Allergies, conditions, medications…',
                          prefixIcon: Icon(Icons.medical_information),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── Emergency contact ───────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Emergency Contact (optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _contactNameController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Name',
                          prefixIcon: Icon(Icons.contact_phone),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _contactPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

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
                  'Your data stays on your device. It is only shared over the mesh when you send an SOS.',
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
