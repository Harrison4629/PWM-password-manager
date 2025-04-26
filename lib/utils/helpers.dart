import 'package:csv/csv.dart';
import '../models/password_entry.dart';

// 基本的 CSV 助手
class CsvHelper {

  // 将 PasswordEntry 列表 (已解密) 转换为 CSV 字符串
  static String toCsv(List<PasswordEntry> entries) {
    // 标题行 + 数据行
    List<List<dynamic>> rows = [
      ['title', 'account', 'password'] // 标题
    ];
    for (var entry in entries) {
      rows.add([entry.title, entry.account, entry.password]);
    }
    return const ListToCsvConverter().convert(rows);
  }

  // 将 CSV 字符串解析为 PasswordEntry 列表 (准备加密)
  // 错误时返回 null
  static List<PasswordEntry>? fromCsv(String csvString) {
    try {
      // 移除 eol: '\n' 以允许自动检测行尾符
      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
      if (rows.isEmpty) return []; // 空 CSV

      // 查找标题索引 (不区分大小写，修剪空格)
      List<dynamic> header = rows[0].map((h) => h.toString().toLowerCase().trim()).toList();
      int titleIndex = header.indexOf('title');
      int accountIndex = header.indexOf('account');
      int passwordIndex = header.indexOf('password');

      // 检查是否存在基本标题
      if (titleIndex == -1 || accountIndex == -1 || passwordIndex == -1) {
        return null;
      }

      List<PasswordEntry> entries = [];
      // 从第 1 行开始 (跳过标题)
      for (int i = 1; i < rows.length; i++) {
         final row = rows[i];
         // 基本检查行长度是否与标题长度匹配
         if (row.length == header.length) {
            entries.add(PasswordEntry(
              // 为导入的项目生成新 ID 和顺序
              title: row[titleIndex].toString(),
              account: row[accountIndex].toString(),
              password: row[passwordIndex].toString(),
              order: entries.length, // 根据导入顺序分配顺序
            ));
         } else {
         }
      }
      return entries;
    } catch (e) {
      return null;
    }
  }
}
