import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';

part 'password_entry.g.dart'; // Hive Generator will create this

@HiveType(typeId: kPasswordEntryTypeId)
class PasswordEntry extends HiveObject {
  @HiveField(0)
  late String id; // Unique ID

  @HiveField(1)
  String title; // Encrypted

  @HiveField(2)
  String account; // Encrypted

  @HiveField(3)
  String password; // Encrypted

  @HiveField(4)
  int order; // For reordering

  PasswordEntry({
    String? id,
    required this.title,
    required this.account,
    required this.password,
    required this.order,
  }) : id = id ?? const Uuid().v4(); // Generate ID if not provided

  // Add copyWith method for easier updates
  PasswordEntry copyWith({
    String? id,
    String? title,
    String? account,
    String? password,
    int? order,
  }) {
    return PasswordEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      account: account ?? this.account,
      password: password ?? this.password,
      order: order ?? this.order,
    );
  }
}