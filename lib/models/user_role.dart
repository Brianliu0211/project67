import 'package:flutter/material.dart';

enum UserRole {
  agent,
  admin,
  dev;

  static UserRole fromString(String? value) {
    if (value == null) return UserRole.agent;
    switch (value.toLowerCase().trim()) {
      case 'admin':
      case 'manager':
        return UserRole.admin;
      case 'dev':
      case 'developer':
        return UserRole.dev;
      case 'agent':
      default:
        return UserRole.agent;
    }
  }

  String get value {
    switch (this) {
      case UserRole.agent:
        return 'agent';
      case UserRole.admin:
        return 'admin';
      case UserRole.dev:
        return 'dev';
    }
  }

  String get labelZh {
    switch (this) {
      case UserRole.agent:
        return '💼 保險業務員 (Agent)';
      case UserRole.admin:
        return '👑 團隊主管 (Manager)';
      case UserRole.dev:
        return '🛠️ 核心開發者 (Dev)';
    }
  }

  String get shortLabel {
    switch (this) {
      case UserRole.agent:
        return '業務員';
      case UserRole.admin:
        return '團隊主管';
      case UserRole.dev:
        return '開發者';
    }
  }

  IconData get badgeIcon {
    switch (this) {
      case UserRole.admin:
        return Icons.military_tech_rounded;
      case UserRole.dev:
        return Icons.code_rounded;
      case UserRole.agent:
        return Icons.verified_user_rounded;
    }
  }

  Color get primaryColor {
    switch (this) {
      case UserRole.admin:
        return const Color(0xFFF59E0B); // Amber / Gold
      case UserRole.dev:
        return const Color(0xFF6366F1); // Indigo / Cyan
      case UserRole.agent:
        return const Color(0xFF10B981); // Emerald Green
    }
  }

  Color get backgroundColor {
    switch (this) {
      case UserRole.admin:
        return const Color(0xFFFEF3C7);
      case UserRole.dev:
        return const Color(0xFFEEF2FF);
      case UserRole.agent:
        return const Color(0xD1ECFDF5);
    }
  }

  bool get isAdmin => this == UserRole.admin;
  bool get isDev => this == UserRole.dev;
  bool get isAgent => this == UserRole.agent;
  bool get hasExtendedPrivileges => this == UserRole.admin || this == UserRole.dev;
}
