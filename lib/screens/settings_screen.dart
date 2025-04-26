import 'dart:convert'; // For utf8 encoding/decoding
import 'dart:io';     // For File operations AND Platform detection
import 'dart:typed_data'; // For Uint8List

import 'package:archive/archive_io.dart'; // For ZIP operations
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart'; // Needed for both import and Windows export
import 'package:encrypt/encrypt.dart' as enc; // For AES encryption/decryption
import 'package:share_plus/share_plus.dart'; // Needed for non-Windows export
import 'package:path_provider/path_provider.dart'; // Needed for non-Windows export

// Project imports
import '../models/password_entry.dart';
import '../providers/auth_providers.dart';
import '../providers/password_providers.dart';
import '../services/encryption_service.dart';
import '../utils/helpers.dart';
import 'pin_setup_screen.dart';
import '../widgets/password_prompt_dialog.dart'; // Assuming this exists

// Constants
const String _appVersion = '1.0.0';
const String _appLegaleseBase = '© {YEAR} harrison\n\n这是一个密码管理器应用。数据存储在本地并加密。加密导出文件需要独立密码。';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // --- Import Logic (Encrypted ZIP - Revised for Android Compatibility) ---
  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    _showSnackBar(context, '请选择要导入的 .pwmenc 文件', durationSeconds: 2);

    try {
      // 1. Pick ANY file type
      print("[Import] Calling pickFiles (type: FileType.any)...");
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false
      );
      print("[Import] pickFiles returned. Result is null: ${result == null}");

      // 2. Validate result and check extension manually
      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        final pickedFile = result.files.single;
        final filePath = pickedFile.path!;
        print("[Import] User picked file: $filePath");

        // Manual Extension Check
        final String fileExtension = filePath.split('.').last.toLowerCase();
        print("[Import] Picked file extension (manual check): $fileExtension");
        if (fileExtension != 'pwmenc') {
          print("[Import] ERROR: Incorrect file type picked ($fileExtension). Expected 'pwmenc'.");
          _showSnackBar(context, '导入失败：请确保选择一个 .pwmenc 后缀的文件');
          return; // Stop processing
        }

        final file = File(filePath);

        // 3. Prompt for password
        final String? importPassword = await showPasswordPromptDialog(
          context: context, // Pass context
          title: '输入文件密码',
          hintText: '请输入导出此文件时设置的密码',
          confirmButtonText: '解密并导入',
        );
        if (importPassword == null || importPassword.isEmpty) { _showSnackBar(context, '导入已取消：未提供密码'); return; }

        _showSnackBar(context, '正在读取和解密文件...', durationSeconds: null);

        // 4. Read, Unzip, Decrypt, Parse, Add...
        Uint8List? salt;
        Uint8List? iv;
        Uint8List? encryptedCsvBytes;
        final bytes = await file.readAsBytes();
        try { // Unzip
          final archive = ZipDecoder().decodeBytes(bytes);
          for (final fileInArchive in archive) {
            if (fileInArchive.name == 'salt.bin') salt = fileInArchive.content as Uint8List;
            if (fileInArchive.name == 'iv.bin') iv = fileInArchive.content as Uint8List;
            if (fileInArchive.name == 'data.encrypted') encryptedCsvBytes = fileInArchive.content as Uint8List;
          }
           print("[Import] ZIP Contents - Salt: ${salt?.length} bytes, IV: ${iv?.length} bytes, Data: ${encryptedCsvBytes?.length} bytes");
        } catch(e, stack) {
           print("[Import] ZIP Decode Error: $e\n$stack");
           _showSnackBar(context, '导入失败：文件格式无效或已损坏');
           return;
        }

        // Validate ZIP contents
        if (salt == null || iv == null || encryptedCsvBytes == null) { _showSnackBar(context, '导入失败：加密文件内容不完整'); return; }
        if (iv.length != 12) { _showSnackBar(context, '导入失败：文件元数据损坏 (IV)'); return; }

        // Derive key
        print("[Import] Deriving key...");
        final importKey = EncryptionService.deriveKey(importPassword, salt);

        // Decrypt
        String csvString;
        try {
          print("[Import] Attempting AES-GCM decryption...");
          final decrypter = enc.Encrypter(enc.AES(enc.Key(importKey), mode: enc.AESMode.gcm));
          final decryptedBytes = decrypter.decryptBytes(enc.Encrypted(encryptedCsvBytes), iv: enc.IV(iv));
          csvString = utf8.decode(decryptedBytes);
          print("[Import] Decryption successful.");
        } catch (e) {
          print("[Import] Decryption FAILED: $e");
          _showSnackBar(context, '解密失败：密码错误或文件无效/已损坏');
          return;
        }

        // Parse CSV
        print("[Import] Parsing CSV data...");
        List<PasswordEntry>? importedEntries = CsvHelper.fromCsv(csvString);

        // Add entries
        if (importedEntries != null) {
           if (importedEntries.isEmpty) { _showSnackBar(context, '导入成功，但文件内容为空'); return; }
           final passwordNotifier = ref.read(passwordListProvider.notifier);
           final currentState = ref.read(passwordListProvider);
           int nextOrder = 0;
           if (currentState is AsyncData<List<PasswordEntry>> && currentState.value.isNotEmpty) { try { nextOrder = currentState.value.map((e) => e.order).reduce((a, b) => a > b ? a : b) + 1; } catch (_) { nextOrder = currentState.value.length; } }
           int addedCount = 0;
           _showSnackBar(context, '正在添加 ${importedEntries.length} 条记录...', durationSeconds: null);
           for (var entry in importedEntries) { await passwordNotifier.addEntry(entry.copyWith(order: nextOrder++)); addedCount++; }
            _showSnackBar(context, '成功导入 $addedCount 条记录');
        } else { _showSnackBar(context, '导入失败：无法解析解密后的 CSV 数据'); }
      } else {
        print("[Import] File picker cancelled or returned invalid result.");
        _showSnackBar(context, '未选择文件或选择无效');
      }
    } catch (e, stackTrace) {
      print("Import Process Error: $e\n$stackTrace");
       _showSnackBar(context, '导入过程中发生意外错误: $e');
    } finally {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }


  // --- Export Logic (Platform-Specific Saving) ---
  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    print("[SettingsScreen._exportCsv] Export process started.");
    final asyncPasswords = ref.read(passwordListProvider);
    if (asyncPasswords is! AsyncData<List<PasswordEntry>>) { _showSnackBar(context, '导出失败：密码列表尚未加载或加载出错'); return; }
    final entries = asyncPasswords.value;
    if (entries.isEmpty) { _showSnackBar(context, '没有可导出的记录'); return; }

    print("[SettingsScreen._exportCsv] Prompting for export password...");
    final String? exportPassword = await showSetPasswordDialog(
        context: context,
        title: '设置导出文件密码',
        passwordHintText: '为加密文件设置新密码',
        confirmHintText: '确认新密码',
        confirmButtonText: '加密并导出',
    );
    if (exportPassword == null || exportPassword.isEmpty) { _showSnackBar(context, '导出已取消：未设置密码'); return; }
     print("[SettingsScreen._exportCsv] Export password obtained.");
     _showSnackBar(context, '正在准备和加密数据...', durationSeconds: null);

    File? tempFile; // For potential cleanup in share logic

    try {
      // --- Steps 1-7: Prepare encrypted ZIP data (Common to all platforms) ---
       print("[Export Step 1] Preparing CSV data...");
       final String csvData = CsvHelper.toCsv(entries); final csvBytes = utf8.encode(csvData);
       print("[Export Step 2] Generating Salt...");
       final exportSalt = EncryptionService.generateSalt();
       print("[Export Step 3] Deriving Key...");
       final exportKey = EncryptionService.deriveKey(exportPassword, exportSalt);
       print("[Export Step 4] Generating IV...");
       final iv = enc.IV.fromSecureRandom(12);
       print("[Export Step 5] Encrypting CSV data...");
       final encrypter = enc.Encrypter(enc.AES(enc.Key(exportKey), mode: enc.AESMode.gcm));
       final encryptedCsvBytes = encrypter.encryptBytes(csvBytes, iv: iv).bytes;
       print("[Export Step 6] Creating Archive object...");
       final archive = Archive();
       archive.addFile(ArchiveFile('salt.bin', exportSalt.length, exportSalt));
       archive.addFile(ArchiveFile('iv.bin', iv.bytes.length, iv.bytes));
       archive.addFile(ArchiveFile('data.encrypted', encryptedCsvBytes.length, encryptedCsvBytes));
       print("[Export Step 7] Encoding ZIP archive...");
       List<int>? zipData;
       try { final zipEncoder = ZipEncoder(); zipData = zipEncoder.encode(archive); } catch (zipError) { throw Exception("ZIP encoding failed: $zipError"); }
       if (zipData == null) throw Exception("Failed to encode ZIP archive (returned null).");
       final zipBytes = Uint8List.fromList(zipData);
       // --- End Steps 1-7 ---

      // --- Step 8: Platform-Specific Saving/Sharing ---
      final defaultFileName = 'pwm_export_${DateTime.now().toIso8601String().split('T')[0]}.pwmenc';

      // Use dart:io Platform check
      if (Platform.isWindows) {
          // --- Windows Logic: Use saveFile to get path, then write manually ---
          print("[Export Step 8 - Windows] Prompting user to save file...");
          String? outputFile = await FilePicker.platform.saveFile(
             dialogTitle: '请选择导出文件的保存位置',
             fileName: defaultFileName,
             // bytes parameter is NOT used or needed by saveFile on Windows
          );
           print("[Export Step 8 - Windows] Save file dialog closed. Output path: $outputFile");

          if (outputFile != null && outputFile.isNotEmpty) {
             // Ensure the extension is present
             if (!outputFile.toLowerCase().endsWith('.pwmenc')) outputFile += '.pwmenc';
             final File file = File(outputFile);
             print("[Export Step 9 - Windows] Writing ${zipBytes.length} ZIP bytes to file: $outputFile");
             await file.writeAsBytes(zipBytes); // Manually write the bytes
             print("[Export Step 9 - Windows] File write complete.");
             _showSnackBar(context, '记录已加密导出到: $outputFile', durationSeconds: 5);
          } else {
             print("[Export - Windows] User cancelled save file dialog or got empty path.");
             _showSnackBar(context, '导出已取消');
          }
          // --- End Windows Logic ---

      } else {
          // --- Android/iOS/Other Logic: Save to temp and use Share Sheet ---
          print("[Export Step 8 - Mobile/Other] Saving to temporary directory...");
          final tempDir = await getTemporaryDirectory();
          final tempFilePath = '${tempDir.path}/$defaultFileName';
          tempFile = File(tempFilePath);
          print("[Export Step 8a - Mobile/Other] Writing ${zipBytes.length} ZIP bytes to temporary file: $tempFilePath");
          await tempFile.writeAsBytes(zipBytes);
          print("[Export Step 8a DONE - Mobile/Other] Temporary file written.");

          print("[Export Step 9 - Mobile/Other] Triggering share sheet for file: $tempFilePath");
          // Create XFile for sharing
          final xFile = XFile(tempFilePath, name: defaultFileName);
          final shareResult = await Share.shareXFiles(
              [xFile],
              subject: 'PWM Exported Data (${DateTime.now().toLocal().toString().substring(0, 16)})',
              text: '保存或分享您的 PWM 加密导出文件 (.pwmenc)。'
          );
          print("[Export Step 9 DONE - Mobile/Other] Share sheet closed. Result status: ${shareResult.status}");

          // Provide feedback based on share result
          if (shareResult.status == ShareResultStatus.success || shareResult.status == ShareResultStatus.dismissed) {
              _showSnackBar(context, '请在弹出的菜单中选择保存位置或分享应用');
          } else {
               _showSnackBar(context, '无法调用分享功能 (${shareResult.status})');
          }
          // --- End Android/iOS/Other Logic ---
      }
      // --- End Step 8 ---

    } catch (e, stackTrace) {
      print("!!! EXPORT PROCESS ERROR !!!\nError: $e\nStackTrace: $stackTrace");
      _showSnackBar(context, '导出过程中发生错误: $e');
    } finally {
         print("[SettingsScreen._exportCsv] Export process finished (finally block).");
         ScaffoldMessenger.of(context).hideCurrentSnackBar();
         // Optional temp file cleanup (use with caution)
         // try { if (tempFile != null && await tempFile.exists()) await tempFile.delete(); } catch (_) {}
    }
  }

  // --- Helper function for showing Snackbars ---
  void _showSnackBar(BuildContext context, String message, {int? durationSeconds = 4}) {
      // Ensure context is still valid if called after async gap
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        duration: durationSeconds == null ? const Duration(days: 1) : Duration(seconds: durationSeconds),
        action: durationSeconds == null ? SnackBarAction(label: '请稍候', onPressed: (){}) : null,
      ));
  }


  // --- Change PIN Logic ---
  void _changePin(BuildContext context) {
     Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => const PinSetupScreen(isChangePinMode: true)),
     );
  }

  // --- Logout Logic ---
   void _logout(BuildContext context, WidgetRef ref) async {
      // Get theme colors before the async gap
      final primaryColor = Theme.of(context).colorScheme.primary;
      final errorColor = Theme.of(context).colorScheme.error;

      final confirm = await showDialog<bool>(
          context: context, // Pass the correct context here
          barrierDismissible: false,
          builder: (BuildContext dialogContext) => AlertDialog(
              title: const Text('确认锁定'),
              content: const Text('您确定要锁定应用并返回密码验证界面吗？'),
              actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text('取消', style: TextStyle(color: errorColor)) // Style cancel button
                  ),
                  TextButton(
                      style: TextButton.styleFrom(foregroundColor: primaryColor), // Style confirm button
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('确认锁定')
                  ),
              ],
          ),
      );
       if (confirm == true) {
          // Perform logout action
          ref.read(authStateProvider.notifier).logout();
          // Do not interact with context after logout
       }
   }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- UI structure ---
    return Scaffold(
      // AppBar is handled by MainLayout
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          // --- Data Import/Export Section ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text("数据导入/导出", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ),
          ListTile(
            leading: const Icon(Icons.file_open_outlined),
            title: const Text('从文件导入 (加密)'),
            subtitle: const Text('导入 .pwmenc 加密文件'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _importCsv(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.save), // Use Share icon
            title: const Text('导出/分享文件 (加密)'),
            subtitle: Text(
              '将所有记录导出为加密的 .pwmenc 文件\n需要为每个文件设置并记住独立密码',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey[700]),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _exportCsv(context, ref), // Calls the revised export function
          ),

          const Divider(height: 24, indent: 16, endIndent: 16),

          // --- Security Section ---
           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text("安全设置", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ),
           ListTile(
              leading: const Icon(Icons.lock_reset_outlined),
              title: const Text('更改主密码'),
              subtitle: const Text('修改用于解锁应用的 6 位密码'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _changePin(context),
           ),
           ListTile(
              leading: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.error),
              title: Text('锁定应用', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              subtitle: const Text('退出当前会话并返回密码验证'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).colorScheme.error),
              onTap: () => _logout(context, ref),
           ),

          const Divider(height: 24, indent: 16, endIndent: 16),

          // --- About Section ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text("关于", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ),
          ListTile(
             leading: const Icon(Icons.info_outline),
             title: const Text('关于 PWM'),
             subtitle: const Text('版本 $_appVersion'), // Use constant
             trailing: const Icon(Icons.arrow_forward_ios, size: 16),
             onTap: () {
               final currentYear = DateTime.now().year;
               final legaleseText = _appLegaleseBase.replaceFirst('{YEAR}', currentYear.toString());
               showAboutDialog(
                 context: context, // Pass context
                 applicationName: 'PWM 密码管理器',
                 applicationVersion: _appVersion, // Use constant
                 applicationIcon: Icon(Icons.shield_moon_outlined, size: 40, color: Theme.of(context).colorScheme.primary),
                 applicationLegalese: legaleseText, // Use constant and dynamic year
               );
             },
           ),
        ],
      ),
    );
  }
}