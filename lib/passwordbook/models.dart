/// 密码本数据模型

class PasswordBook {
  final String id;
  final String? ownerId;
  final String name;
  final String? description;
  final int allowedType;
  final int minLength;
  final int maxLength;
  final String? creationTime;
  final String? lastModificationTime;
  final bool isDeleted;
  final int entryCount;
  final List<PasswordEntry> passwordEntries;

  PasswordBook({
    required this.id,
    this.ownerId,
    required this.name,
    this.description,
    required this.allowedType,
    required this.minLength,
    required this.maxLength,
    this.creationTime,
    this.lastModificationTime,
    this.isDeleted = false,
    this.entryCount = 0,
    this.passwordEntries = const [],
  });

  factory PasswordBook.fromJson(Map<String, dynamic> json) {
    return PasswordBook(
      id: json['id'] ?? '',
      ownerId: json['ownerId'],
      name: json['name'] ?? '',
      description: json['description'],
      allowedType: json['allowedType'] ?? 1,
      minLength: json['minLength'] ?? 8,
      maxLength: json['maxLength'] ?? 20,
      creationTime: json['creationTime'],
      lastModificationTime: json['lastModificationTime'],
      isDeleted: json['isDeleted'] ?? false,
      entryCount: json['entryCount'] ?? 0,
      passwordEntries: (json['passwordEntries'] as List<dynamic>?)
              ?.map((e) => PasswordEntry.fromJson(e))
              .toList() ??
          [],
    );
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
  final String? creationTime;
  final String? lastModificationTime;
  final List<PasswordHistory> passwordHistories;

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
    this.isDeleted = false,
    this.creationTime,
    this.lastModificationTime,
    this.passwordHistories = const [],
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
      creationTime: json['creationTime'],
      lastModificationTime: json['lastModificationTime'],
      passwordHistories: (json['passwordHistories'] as List<dynamic>?)
              ?.map((e) => PasswordHistory.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class PasswordHistory {
  final String id;
  final String passwordEntryId;
  final String passwordValue;
  final bool isCurrent;
  final String? creationTime;

  PasswordHistory({
    required this.id,
    required this.passwordEntryId,
    required this.passwordValue,
    this.isCurrent = false,
    this.creationTime,
  });

  factory PasswordHistory.fromJson(Map<String, dynamic> json) {
    return PasswordHistory(
      id: json['id'] ?? '',
      passwordEntryId: json['passwordEntryId'] ?? '',
      passwordValue: json['passwordValue'] ?? '',
      isCurrent: json['isCurrent'] ?? false,
      creationTime: json['creationTime'],
    );
  }
}

class PasswordBookListResponse {
  final List<PasswordBook> items;

  PasswordBookListResponse({required this.items});

  factory PasswordBookListResponse.fromJson(Map<String, dynamic> json) {
    return PasswordBookListResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => PasswordBook.fromJson(e))
              .toList() ??
          [],
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