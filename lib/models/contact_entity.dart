import 'package:equatable/equatable.dart';

class ContactEntity extends Equatable {
  final String id;
  final String ownerId;
  final String contactId;
  final String name;
  final String email;
  final String? photoUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContactEntity({
    required this.id,
    required this.ownerId,
    required this.contactId,
    required this.name,
    required this.email,
    this.photoUrl,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  ContactEntity copyWith({
    String? id,
    String? ownerId,
    String? contactId,
    String? name,
    String? email,
    String? photoUrl,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContactEntity(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      contactId: contactId ?? this.contactId,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id, 
    ownerId, 
    contactId, 
    name, 
    email, 
    photoUrl, 
    notes, 
    createdAt,
    updatedAt,
  ];
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'contactId': contactId,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ContactEntity.fromMap(Map<String, dynamic> map) {
    return ContactEntity(
      id: map['id'] ?? '',
      ownerId: map['ownerId'] ?? '',
      contactId: map['contactId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      notes: map['notes'],
      createdAt: map['createdAt'] is int 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt']) 
          : (map['createdAt'] is DateTime 
              ? map['createdAt'] 
              : map['createdAt']?.toDate() ?? DateTime.now()),
      updatedAt: map['updatedAt'] is int 
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt']) 
          : (map['updatedAt'] is DateTime 
              ? map['updatedAt'] 
              : map['updatedAt']?.toDate() ?? DateTime.now()),
    );
  }
} 