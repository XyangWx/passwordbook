/// 密码本数据模型

class PasswordBook {
  final String id;
  final String name;
  final String? description;
  final int allowedType;
  final int minLength;
  final int maxLength;
  final String? creationTime;
  final int entryCount;

  PasswordBook({
    required this.id,
    required this.name,
    this.description,
    required this.allowedType,
    required this.minLength,
    required this.maxLength,
    this.creationTime,
    this.entryCount = 0,
  });

  factory PasswordBook.fromJson(Map<String, dynamic> json) {
    return PasswordBook(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      allowedType: json['allowedType'] ?? 1,
      minLength: json['minLength'] ?? 8,
      maxLength: json['maxLength'] ?? 20,
      creationTime: json['creationTime'],
      entryCount: json['entryCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'allowedType': allowedType,
      'minLength': minLength,
      'maxLength': maxLength,
    };
  }
}

class PasswordEntry {
  final String id;
  final String passwordBookId;
  final String title;
  final bool hasUsername;
  final String? username;
  final int passwordType;
  final int? weakLevel;
  final String? remark;
  final String? currentPassword;
  final bool isDeleted;

  PasswordEntry({
    required this.id,
    required this.passwordBookId,
    required this.title,
    required this.hasUsername,
    this.username,
    required this.passwordType,
    this.weakLevel,
    this.remark,
    this.currentPassword,
    required this.isDeleted,
  });

  factory PasswordEntry.fromJson(Map<String, dynamic> json) {
    return PasswordEntry(
      id: json['id'] ?? '',
      passwordBookId: json['passwordBookId'] ?? '',
      title: json['title'] ?? '',
      hasUsername: json['hasUsername'] ?? false,
      username: json['username'],
      passwordType: json['passwordType'] ?? 1,
      weakLevel: json['weakLevel'],
      remark: json['remark'],
      currentPassword: json['currentPassword'],
      isDeleted: json['isDeleted'] ?? false,
    );
  }
}

enum AllowedType {
  numericOnly(0, 'NumericOnly'),
  general(1, 'General');

  const AllowedType(this.value, this.label);
  final int value;
  final String label;
}

enum WeakLevel {
  veryWeak(0, 'VeryWeak'),
  weak(1, 'Weak'),
  medium(2, 'Medium'),
  strong(3, 'Strong'),
  veryStrong(4, 'VeryStrong');

  const WeakLevel(this.value, this.label);
  final int value;
  final String label;
}