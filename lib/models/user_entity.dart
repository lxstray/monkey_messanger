import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String role;
  final DateTime createdAt;
  final DateTime lastActive;
  final bool isOnline;
  final bool is2faEnabled;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.role,
    required this.createdAt,
    required this.lastActive,
    required this.isOnline,
    this.is2faEnabled = false,
  });

  UserEntity copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
    String? role,
    DateTime? createdAt,
    DateTime? lastActive,
    bool? isOnline,
    bool? is2faEnabled,
  }) {
    return UserEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      isOnline: isOnline ?? this.isOnline,
      is2faEnabled: is2faEnabled ?? this.is2faEnabled,
    );
  }

  @override
  List<Object?> get props => [
    id, 
    name, 
    email, 
    photoUrl, 
    role, 
    createdAt,
    lastActive,
    isOnline,
    is2faEnabled,
  ];
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastActive': lastActive.millisecondsSinceEpoch,
      'isOnline': isOnline,
      '2faEnabled': is2faEnabled,
    };
  }

  factory UserEntity.fromMap(Map<String, dynamic> map) {
    return UserEntity(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      role: map['role'] ?? 'user',
      createdAt: map['createdAt'] is int 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt']) 
          : (map['createdAt'] is DateTime 
              ? map['createdAt'] 
              : map['createdAt']?.toDate() ?? DateTime.now()),
      lastActive: map['lastActive'] is int 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastActive']) 
          : (map['lastActive'] is DateTime 
              ? map['lastActive'] 
              : map['lastActive']?.toDate() ?? DateTime.now()),
      isOnline: map['isOnline'] ?? false,
      is2faEnabled: map['2faEnabled'] ?? false,
    );
  }
} 