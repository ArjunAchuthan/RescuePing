/// Role of the user within the rescue system.
enum UserRole {
  rescuer,
  needHelp;

  String get wire => name;

  static UserRole fromWire(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserRole.needHelp,
    );
  }
}

/// Emergency profile stored locally for the current user.
///
/// This information is included in SOS packets so rescuers can see
/// critical details (blood group, medical notes, etc.) without asking.
class UserProfile {
  const UserProfile({
    required this.nickname,
    this.role = UserRole.needHelp,
    this.bloodGroup = '',
    this.medicalNotes = '',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.peopleCount = 1,
  });

  final String nickname;

  /// Whether this user is a rescuer or someone who needs help.
  final UserRole role;

  /// e.g. "A+", "O−", "AB+"
  final String bloodGroup;

  /// Free-text: allergies, chronic conditions, medications, etc.
  final String medicalNotes;

  final String emergencyContactName;
  final String emergencyContactPhone;

  /// Number of people with this user (default 1 = self only).
  final int peopleCount;

  UserProfile copyWith({
    String? nickname,
    UserRole? role,
    String? bloodGroup,
    String? medicalNotes,
    String? emergencyContactName,
    String? emergencyContactPhone,
    int? peopleCount,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      role: role ?? this.role,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      peopleCount: peopleCount ?? this.peopleCount,
    );
  }

  Map<String, Object?> toJson() => {
    'nickname': nickname,
    'role': role.wire,
    'bloodGroup': bloodGroup,
    'medicalNotes': medicalNotes,
    'emergencyContactName': emergencyContactName,
    'emergencyContactPhone': emergencyContactPhone,
    'peopleCount': peopleCount,
  };

  static UserProfile fromJson(Map<String, Object?> json) {
    return UserProfile(
      nickname: (json['nickname'] as String?) ?? '',
      role: UserRole.fromWire((json['role'] as String?) ?? 'needHelp'),
      bloodGroup: (json['bloodGroup'] as String?) ?? '',
      medicalNotes: (json['medicalNotes'] as String?) ?? '',
      emergencyContactName: (json['emergencyContactName'] as String?) ?? '',
      emergencyContactPhone: (json['emergencyContactPhone'] as String?) ?? '',
      peopleCount: (json['peopleCount'] as int?) ?? 1,
    );
  }
}
