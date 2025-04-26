import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for Clipboard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart'; // For generating ID
import '../models/password_entry.dart';
import '../providers/password_providers.dart';

class AddEditScreen extends ConsumerStatefulWidget {
  final PasswordEntry? entry; // Pass entry if editing

  const AddEditScreen({super.key, this.entry});

  @override
  ConsumerState<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends ConsumerState<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _accountController;
  late TextEditingController _passwordController;
  bool _isPasswordVisible = false;
  bool _isEditing = false;
  bool _isSaving = false; // Add saving state flag

  @override
  void initState() {
    super.initState();
    _isEditing = widget.entry != null;
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _accountController = TextEditingController(text: widget.entry?.account ?? '');
    _passwordController = TextEditingController(text: widget.entry?.password ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Updated _saveEntry Method ---
  Future<void> _saveEntry() async { // Make async to handle potential errors
    if (_isSaving) return; // Prevent double taps

    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true); // Set saving state

      final passwordNotifier = ref.read(passwordListProvider.notifier);
      // Read the AsyncValue state safely
      final asyncListState = ref.read(passwordListProvider);

      // Determine the next order index
      int nextOrderIndex = 0; // Default to 0 if list state is uncertain/empty

      if (asyncListState is AsyncData<List<PasswordEntry>>) {
        final currentEntries = asyncListState.value; // Get the actual list
        if (currentEntries.isNotEmpty) {
          // Use length as the next index (assuming orders are contiguous)
          // nextOrderIndex = currentEntries.length;
          // More robust way: find max order + 1
           try {
             nextOrderIndex = currentEntries.map((e) => e.order).reduce((a, b) => a > b ? a : b) + 1;
           } catch (e) {
             // Handle case where list might be empty after filtering or error during reduce
             print("Could not determine max order, defaulting to length or 0. Error: $e");
             nextOrderIndex = currentEntries.length; // Fallback to length
           }
        }
        // If currentEntries is empty, nextOrderIndex remains 0
      } else {
        // Handle loading/error - using 0 as a fallback
        print("Warning: Password list state is not AsyncData (${asyncListState.runtimeType}). Defaulting order for new entry to 0.");
      }

      final entry = PasswordEntry(
        id: widget.entry?.id ?? const Uuid().v4(), // Use existing ID or generate new
        title: _titleController.text.trim(),
        account: _accountController.text.trim(),
        password: _passwordController.text.trim(),
        // Use existing order if editing, otherwise use the calculated nextOrderIndex
        order: widget.entry?.order ?? nextOrderIndex,
      );

      try {
        if (_isEditing) {
          await passwordNotifier.updateEntry(entry); // Await the async operation
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('记录已更新')));
            Navigator.pop(context); // Pop only after successful update
          }
        } else {
          await passwordNotifier.addEntry(entry); // Await the async operation
           if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('记录已添加')));
            Navigator.pop(context); // Pop only after successful add
          }
        }
      } catch (e) {
         // Handle errors from the notifier/storage service
         print("Error saving entry: $e");
         if (mounted) {
            ScaffoldMessenger.of(context)
               ..hideCurrentSnackBar()
               ..showSnackBar(SnackBar(content: Text('保存失败: ${e.toString()}')));
         }
      } finally {
          if (mounted) {
            setState(() => _isSaving = false); // Reset saving state
          }
      }
    }
  }

  // --- Updated Delete Logic (Async Confirmation) ---
   Future<void> _deleteEntry() async {
       if (widget.entry == null) return; // Should not happen if delete button is shown

       final confirm = await showDialog<bool>(
         context: context,
         builder: (BuildContext context) {
           return AlertDialog(
             title: const Text('确认删除'),
             content: const Text('确定要删除这条记录吗？此操作无法撤销。'),
             actions: <Widget>[
               TextButton(
                 child: const Text('取消'),
                 onPressed: () => Navigator.of(context).pop(false),
               ),
               TextButton(
                 style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                 child: const Text('删除'),
                 onPressed: () => Navigator.of(context).pop(true),
               ),
             ],
           );
         },
       );

       if (confirm == true) {
         setState(() => _isSaving = true); // Indicate processing
         try {
           // Use ref.read in callbacks/async functions
           await ref.read(passwordListProvider.notifier).deleteEntry(widget.entry!.id);
           if (mounted) {
             ScaffoldMessenger.of(context)
               ..hideCurrentSnackBar()
               ..showSnackBar(const SnackBar(content: Text('记录已删除')));
             Navigator.pop(context); // Go back after successful delete
           }
         } catch (e) {
           print("Error deleting entry: $e");
           if (mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text('删除失败: ${e.toString()}')));
           }
         } finally {
             if (mounted) {
               setState(() => _isSaving = false); // Reset processing state
             }
         }
       }
   }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑记录' : '添加新记录'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除此记录',
              // Call the async delete method, disable button while saving/deleting
              onPressed: _isSaving ? null : _deleteEntry,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  hintText: '例如：网站名称、应用名称',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '标题不能为空';
                  }
                  return null;
                },
                enabled: !_isSaving, // Disable fields while saving
              ),
              const SizedBox(height: 16),
              // --- Account Field with Copy Button ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, // Center items vertically
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _accountController,
                      decoration: const InputDecoration(
                        labelText: '账号',
                        hintText: '例如：用户名、邮箱、手机号',
                        prefixIcon: Icon(Icons.account_circle_outlined),
                        // No suffix icon inside the account field
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '账号不能为空';
                        }
                        return null;
                      },
                      enabled: !_isSaving,
                    ),
                  ),
                  // Add some spacing before the button
                  const SizedBox(width: 8),
                  // Copy Button for Account (Outside)
                  IconButton(
                    icon: const Icon(Icons.content_copy, size: 20),
                    tooltip: '复制账号',
                    // Remove extra padding, rely on Row's crossAxisAlignment
                    padding: EdgeInsets.zero, // Adjust if needed
                    constraints: const BoxConstraints(), // Remove default large padding
                    onPressed: _isSaving || _accountController.text.isEmpty
                        ? null // Disable if saving or field is empty
                        : () {
                            Clipboard.setData(ClipboardData(text: _accountController.text));
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(const SnackBar(
                                content: Text('账号已复制到剪贴板'),
                                duration: Duration(seconds: 2),
                              ));
                          },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // --- Password Field with Visibility (Inside) and Copy (Outside) Buttons ---
              Row(
                 crossAxisAlignment: CrossAxisAlignment.center, // Center items vertically
                 children: [
                   Expanded(
                     child: TextFormField(
                       controller: _passwordController,
                       obscureText: !_isPasswordVisible,
                       keyboardType: TextInputType.visiblePassword,
                       autocorrect: false,
                       enableSuggestions: false,
                       decoration: InputDecoration( // Add InputDecoration here
                         labelText: '密码',
                         prefixIcon: const Icon(Icons.lock_outline),
                         // Visibility toggle button INSIDE the text field border
                         suffixIcon: IconButton(
                           icon: Icon(
                             _isPasswordVisible
                                 ? Icons.visibility_off_outlined
                                 : Icons.visibility_outlined,
                             size: 20,
                           ),
                           tooltip: _isPasswordVisible ? '隐藏密码' : '显示密码',
                           onPressed: _isSaving ? null : () {
                             setState(() {
                               _isPasswordVisible = !_isPasswordVisible;
                             });
                           },
                         ),
                       ),
                       validator: (value) {
                         if (value == null || value.isEmpty) {
                           return '密码不能为空';
                         }
                         return null;
                       },
                       enabled: !_isSaving,
                     ),
                    ),
                    const SizedBox(width: 8),
                    // Copy Button for Password (Outside)
                    IconButton(
                      icon: const Icon(Icons.content_copy, size: 20),
                      tooltip: '复制密码',
                      padding: EdgeInsets.zero, // Adjust if needed
                      constraints: const BoxConstraints(), // Remove default large padding
                      onPressed: _isSaving || _passwordController.text.isEmpty
                          ? null // Disable if saving or field is empty
                          : () {
                              Clipboard.setData(ClipboardData(text: _passwordController.text));
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(const SnackBar(
                                  content: Text('密码已复制到剪贴板'),
                                  duration: Duration(seconds: 2),
                                ));
                            },
                    ),
                  ],
               ),
              const SizedBox(height: 32),
              // Show progress indicator or button based on saving state
              _isSaving
                ? const Center(child: CircularProgressIndicator())
                // Correctly place the ElevatedButton after the ternary operator
                : ElevatedButton.icon(
                   icon: const Icon(Icons.save_alt_outlined),
                   label: Text(_isEditing ? '保存更改' : '保存记录'),
                   onPressed: _saveEntry, // Call async save method
                 ),
            ],
          ),
        ),
      ),
    );
  }
}
