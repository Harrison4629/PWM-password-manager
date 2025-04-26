import 'package:flutter/material.dart';

const String kHiveBoxName = 'passwordEntriesBox';
const int kPasswordEntryTypeId = 0; // Hive 类型 ID

const String kPrefsPinSetKey = 'isPinSet';
const String kPrefsPinSaltKey = 'pinSalt';
const String kPrefsPinHashKey = 'pinHash';

const int kPbkdf2Iterations = 1000; // 迭代次数，越高越安全但越慢
const int kPbkdf2SaltSize = 16;    // 盐长度 (bytes)
const int kPbkdf2KeyLength = 32;   // 派生密钥长度 (bytes, for AES-256)
const int kPbkdf2HashLength = 32;  // 存储的验证哈希长度 (bytes)

// Google-like Colors
const Color kPrimaryColor = Colors.blue; // 主题强调色 (Material Blue 500)
const Color kAppBarFooterColor = Color(0xFFBBDEFB); // 淡 Blue (Material Blue 100)
const Color kContentBackgroundColor = Colors.white; // 内容区背景色
