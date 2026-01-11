import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ ضروري للنسخ
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart' as intl;
import 'package:pocketbase/pocketbase.dart';
import 'services/notice_service.dart';
import 'services/pb_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  final bool _canAdd = true;
  final String _superAdminId = "1sxo74splxbw1yh";
  String _currentUserId = "";

  @override
  void initState() {
    super.initState();
    final user = NoticeService().pb.authStore.record;
    _currentUserId = user?.id ?? "";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(" الإشعارات"), centerTitle: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: PBHelper().getCollectionStream(
              'announcements',
              sort: '-created',
              expand: 'seen_by,target_users,user',
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());

              final allNotices = snapshot.data ?? [];
              final notices = allNotices.where((notice) {
                if (_currentUserId == _superAdminId) return true;
                if (notice['user'] == _currentUserId) return true;
                String createdBy = notice['created_by'] ?? '';
                if (createdBy == _currentUserId) return true;

                List<dynamic> targets = notice['target_users'] ?? [];
                if (targets.isEmpty) return true;
                return targets.contains(_currentUserId);
              }).toList();

              if (notices.isEmpty)
                return const Center(child: Text("لا توجد اشعارات"));

              return ListView.separated(
                padding: const EdgeInsets.only(
                  top: 16,
                  left: 16,
                  right: 16,
                  bottom: 100,
                ),
                itemCount: notices.length,
                separatorBuilder: (c, i) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return NoticeCard(
                    notice: notices[index],
                    currentUserId: _currentUserId,
                    superAdminId: _superAdminId,
                    onEdit: () async {
                      await showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => AddEditNoticeDialog(
                          existingNotice: notices[index],
                          currentUserId: _currentUserId,
                          superAdminId: _superAdminId,
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: _canAdd
          ? FloatingActionButton.extended(
              onPressed: () async {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AddEditNoticeDialog(
                    currentUserId: _currentUserId,
                    superAdminId: _superAdminId,
                  ),
                );
                if (mounted) setState(() {});
              },
              label: const Text("اشعار جديد"),
              icon: const Icon(Icons.add),
              backgroundColor: const Color(0xFF1565C0),
            )
          : null,
    );
  }
}

// =========================================================
// 🚀 نافذة الإضافة/التعديل (مفصولة لتسريع الأداء)
// =========================================================
class AddEditNoticeDialog extends StatefulWidget {
  final Map<String, dynamic>? existingNotice;
  final String currentUserId;
  final String superAdminId;

  const AddEditNoticeDialog({
    super.key,
    this.existingNotice,
    required this.currentUserId,
    required this.superAdminId,
  });

  @override
  State<AddEditNoticeDialog> createState() => _AddEditNoticeDialogState();
}

class _AddEditNoticeDialogState extends State<AddEditNoticeDialog> {
  late TextEditingController titleCtrl;
  late quill.QuillController _quillController;
  late String priority;

  List<PlatformFile> selectedFiles = [];
  List<String> existingImages = [];
  List<String> selectedUserIds = [];
  bool isAllEmployees = true;
  bool isEdit = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    isEdit = widget.existingNotice != null;

    titleCtrl = TextEditingController(
      text: isEdit ? widget.existingNotice!['title'] : '',
    );

    priority = isEdit
        ? (widget.existingNotice!['priority'] ?? 'normal')
        : 'normal';

    if (isEdit && widget.existingNotice!['image'] != null) {
      existingImages = List<String>.from(
        widget.existingNotice!['image'] is List
            ? widget.existingNotice!['image']
            : [widget.existingNotice!['image']],
      );
    }

    if (isEdit) {
      List<dynamic> targets = widget.existingNotice!['target_users'] ?? [];
      if (targets.isNotEmpty) {
        isAllEmployees = false;
        selectedUserIds = targets.map((e) => e.toString()).toList();
      }
    }

    quill.Document doc = quill.Document();
    if (isEdit && widget.existingNotice!['content'] != null) {
      try {
        doc = quill.Document.fromJson(
          jsonDecode(widget.existingNotice!['content']),
        );
      } catch (e) {
        doc = quill.Document()..insert(0, widget.existingNotice!['content']);
      }
    }
    _quillController = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    _quillController.dispose();
    super.dispose();
  }

  Future<void> pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf', 'doc', 'docx'],
    );
    if (result != null) {
      setState(() => selectedFiles.addAll(result.files));
    }
  }

  Future<void> pickUsers() async {
    List<RecordModel> allUsers = await NoticeService().getUsersNoticesScreen();
    allUsers.removeWhere(
      (u) => u.id == widget.superAdminId || u.id == widget.currentUserId,
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (innerCtx) {
        List<String> tempSelected = List.from(selectedUserIds);
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text("تحديد الموظفين"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allUsers.length,
                  itemBuilder: (c, i) {
                    final u = allUsers[i];
                    final isSelected = tempSelected.contains(u.id);
                    String name =
                        u.data['name']?.toString() ??
                        u.data['username'] ??
                        "Unknown";
                    return CheckboxListTile(
                      title: Text(name),
                      value: isSelected,
                      onChanged: (val) {
                        setInnerState(() {
                          if (val == true)
                            tempSelected.add(u.id);
                          else
                            tempSelected.remove(u.id);
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(innerCtx),
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedUserIds = tempSelected;
                      if (selectedUserIds.isEmpty) isAllEmployees = true;
                    });
                    Navigator.pop(innerCtx);
                  },
                  child: const Text("تأكيد"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    if (titleCtrl.text.isNotEmpty && !_quillController.document.isEmpty()) {
      setState(() => _isLoading = true);
      try {
        String contentJson = jsonEncode(
          _quillController.document.toDelta().toJson(),
        );
        List<File> filesToUpload = selectedFiles
            .map((e) => File(e.path!))
            .toList();

        if (isEdit) {
          await NoticeService().updateAnnouncement(
            widget.existingNotice!['id'],
            titleCtrl.text,
            contentJson,
            priority,
            targetUserIds: isAllEmployees ? null : selectedUserIds,
          );
        } else {
          await NoticeService().createAnnouncement(
            titleCtrl.text,
            contentJson,
            priority,
            files: filesToUpload,
            targetUserIds: isAllEmployees ? [] : selectedUserIds,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("تم النشر بنجاح ✅"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("برجاء إدخال البيانات المطلوبة")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    Color activeColor = getPriorityColor(priority);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      insetPadding: EdgeInsets.all(isMobile ? 10 : 20),
      child: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : Container(
              width: isMobile ? size.width : 550,
              constraints: BoxConstraints(maxHeight: size.height * 0.9),
              padding: const EdgeInsets.all(15),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isEdit ? Icons.edit : Icons.edit_note,
                          color: activeColor,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isEdit ? "تعديل الاشعار" : "تنبيه جديد",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildModernChip(
                          "low",
                          "low",
                          priority,
                          (v) => setState(() => priority = v),
                        ),
                        _buildModernChip(
                          "normal",
                          "normal",
                          priority,
                          (v) => setState(() => priority = v),
                        ),
                        _buildModernChip(
                          "high",
                          "high",
                          priority,
                          (v) => setState(() => priority = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    InkWell(
                      onTap: () {
                        setState(() => isAllEmployees = !isAllEmployees);
                        if (!isAllEmployees) pickUsers();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: isDark ? Colors.black12 : Colors.grey[50],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isAllEmployees ? Icons.public : Icons.people,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isAllEmployees
                                    ? "موجه لجميع الموظفين"
                                    : "تم تحديد ${selectedUserIds.length} موظف",
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            if (!isAllEmployees)
                              IconButton(
                                icon: const Icon(Icons.settings, size: 20),
                                onPressed: pickUsers,
                              )
                            else
                              Switch(
                                value: isAllEmployees,
                                onChanged: (v) {
                                  setState(() {
                                    isAllEmployees = v;
                                    if (v)
                                      selectedUserIds.clear();
                                    else
                                      pickUsers();
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: "موضوع الاشعار",
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF252525)
                            : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.title, color: activeColor),
                      ),
                    ),
                    const SizedBox(height: 15),
                    if (selectedFiles.isNotEmpty || existingImages.isNotEmpty)
                      Container(
                        height: 70,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ...existingImages.map((img) {
                              String ext = img.split('.').last.toLowerCase();
                              bool isDoc =
                                  ext == 'pdf' || ext == 'doc' || ext == 'docx';
                              String url = PBHelper().getImageUrl(
                                widget.existingNotice!['collectionId'],
                                widget.existingNotice!['id'],
                                img,
                              );
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: isDoc
                                      ? const Icon(
                                          Icons.description,
                                          color: Colors.blue,
                                        )
                                      : Image.network(url, fit: BoxFit.cover),
                                ),
                              );
                            }),
                            ...selectedFiles.map((f) {
                              String ext = f.extension?.toLowerCase() ?? "";
                              bool isDoc =
                                  ext == 'pdf' || ext == 'doc' || ext == 'docx';
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: isDoc
                                          ? const Icon(
                                              Icons.description,
                                              color: Colors.blue,
                                            )
                                          : Image.file(
                                              File(f.path!),
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: InkWell(
                                        onTap: () => setState(
                                          () => selectedFiles.remove(f),
                                        ),
                                        child: const CircleAvatar(
                                          radius: 10,
                                          backgroundColor: Colors.red,
                                          child: Icon(
                                            Icons.close,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF252525)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey[200],
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: quill.QuillSimpleToolbar(
                              controller: _quillController,
                              config: const quill.QuillSimpleToolbarConfig(
                                showFontFamily: false,
                                showFontSize: false,
                                showSearchButton: false,
                                showInlineCode: false,
                                showSubscript: false,
                                showSuperscript: false,
                                showBackgroundColorButton: false,
                                showColorButton: false,
                                showCodeBlock: false,
                                showQuote: false,
                                showIndent: false,
                                showLink: false,
                                showUndo: false,
                                showRedo: false,
                                showClipboardCut: false,
                                showClipboardCopy: false,
                                showClipboardPaste: false,
                                multiRowsDisplay: false,
                                showBoldButton: true,
                                showItalicButton: true,
                                showUnderLineButton: true,
                                showListNumbers: true,
                                showListBullets: true,
                                showDirection: true,
                              ),
                            ),
                          ),
                          Container(
                            constraints: const BoxConstraints(
                              minHeight: 150,
                              maxHeight: 250,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: quill.QuillEditor.basic(
                              controller: _quillController,
                              config: const quill.QuillEditorConfig(
                                placeholder: 'اكتب التفاصيل هنا...',
                                autoFocus: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: pickFiles,
                        icon: const Icon(Icons.attach_file, size: 20),
                        label: Text(
                          "إرفاق ملفات (${selectedFiles.length + existingImages.length})",
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          isEdit ? Icons.save : Icons.send_rounded,
                          color: Colors.white,
                        ),
                        label: Text(
                          isEdit ? "حفظ التعديلات" : "نشر الآن",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModernChip(
    String label,
    String value,
    String groupVal,
    Function(String) onTap,
  ) {
    bool isSelected = value == groupVal;
    Color color = getPriorityColor(value);
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey[400]!,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// =========================================================
// 🎨 كارت الإشعار (بنفس الستايل القديم ولكن سريع 🚀)
// =========================================================
class NoticeCard extends StatefulWidget {
  final Map<String, dynamic> notice;
  final String currentUserId;
  final String superAdminId;
  final VoidCallback onEdit;

  const NoticeCard({
    super.key,
    required this.notice,
    required this.currentUserId,
    required this.superAdminId,
    required this.onEdit,
  });

  @override
  State<NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<NoticeCard> {
  late quill.QuillController _readOnlyController;
  late quill.Document _doc;

  @override
  void initState() {
    super.initState();
    try {
      _doc = quill.Document.fromJson(jsonDecode(widget.notice['content']));
    } catch (e) {
      _doc = quill.Document()..insert(0, widget.notice['content']);
    }
    _readOnlyController = quill.QuillController(
      document: _doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  // ✅ دالة نسخ النص (الخاصية الجديدة)
  Future<void> _copyToClipboard() async {
    try {
      String text = _readOnlyController.document.toPlainText().trim();
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("تم نسخ النص بنجاح ✅")));
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _openFile(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("تعذر فتح الملف")));
      }
    }
  }

  void _openImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(url),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSeenByList(BuildContext context) {
    List<dynamic> seenUsers = [];
    if (widget.notice['expand'] != null &&
        widget.notice['expand']['seen_by'] != null) {
      var data = widget.notice['expand']['seen_by'];
      seenUsers = data is List ? data : [data];
    }
    if (seenUsers.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "المشاهدات (${seenUsers.length})",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.separated(
                itemCount: seenUsers.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = seenUsers[index];
                  String name =
                      user['name']?.toString() ?? user['username'] ?? "موظف";
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[50],
                      child: Text(
                        name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String priority = widget.notice['priority'] ?? 'normal';
    Color priorityColor = getPriorityColor(priority);
    Color bgColor = getPriorityBg(priority, isDark);

    bool isOwner = widget.notice['user'] == widget.currentUserId;
    bool isAdmin = widget.currentUserId == widget.superAdminId;
    bool canControl = isOwner || isAdmin;
    List<String> seenByIds = List<String>.from(widget.notice['seen_by'] ?? []);
    bool isSeen = seenByIds.contains(widget.currentUserId);

    List<String> files = [];
    if (widget.notice['image'] != null) {
      files = List<String>.from(
        widget.notice['image'] is List
            ? widget.notice['image']
            : [widget.notice['image']],
      );
    }

    String senderName = "الإدارة";
    if (widget.notice['expand'] != null &&
        widget.notice['expand']['user'] != null) {
      senderName =
          widget.notice['expand']['user']['name'] ??
          widget.notice['expand']['user']['username'] ??
          "موظف";
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: priorityColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. الرأس (Header)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: const Icon(Icons.person, size: 20, color: Colors.grey),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        intl.DateFormat('yyyy-MM-dd hh:mm a').format(
                          DateTime.parse(widget.notice['created']).toLocal(),
                        ),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    getPriorityText(priority),
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // ✅ زر النسخ الجديد (للجميع)
                const SizedBox(width: 5),
                InkWell(
                  onTap: _copyToClipboard,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.copy, size: 18, color: Colors.grey[600]),
                  ),
                ),

                if (canControl) ...[
                  const SizedBox(width: 5),
                  InkWell(
                    onTap: widget.onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _confirmDelete(context, widget.notice['id']),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 2. المحتوى (Quill Editor) - معدل ليكون سريعاً 🚀
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.notice['title'] != null &&
                    widget.notice['title'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      widget.notice['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),

                // 🔥🔥 السر هنا: IgnorePointer + تحديد الارتفاع + تعطيل التفاعل
                Container(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                  ), // يمنع التمدد اللانهائي
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black12 : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IgnorePointer(
                    ignoring: true,
                    child: quill.QuillEditor.basic(
                      controller: _readOnlyController,
                      config: const quill.QuillEditorConfig(
                        showCursor: false,
                        autoFocus: false,
                        enableInteractiveSelection: false, // 🚫 تعطيل التحديد
                        enableSelectionToolbar: false, // 🚫 تعطيل القائمة
                        checkBoxReadOnly: true,
                        scrollable: true, // 🚫 منع السكرول الداخلي
                        expands: false,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),

                // 3. قائمة الملفات (Files List)
                if (files.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: files.length,
                        separatorBuilder: (c, i) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          String fileId = files[index];
                          String url = PBHelper().getImageUrl(
                            widget.notice['collectionId'],
                            widget.notice['id'],
                            fileId,
                          );
                          String ext = fileId.split('.').last.toLowerCase();
                          bool isDoc =
                              ext == 'pdf' || ext == 'doc' || ext == 'docx';
                          return GestureDetector(
                            onTap: () => (isDoc)
                                ? _openFile(url)
                                : _openImage(context, url),
                            child: Container(
                              width: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                                image: (isDoc)
                                    ? null
                                    : DecorationImage(
                                        image: NetworkImage(url),
                                        fit: BoxFit.cover,
                                      ),
                                color: (isDoc) ? Colors.grey[100] : null,
                              ),
                              child: (isDoc)
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            ext == 'pdf'
                                                ? Icons.picture_as_pdf
                                                : Icons.description,
                                            color: ext == 'pdf'
                                                ? Colors.red
                                                : Colors.blue,
                                            size: 24,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            ext.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 4. التذييل (Footer) - المشاهدة وتأكيد القراءة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (canControl)
                  InkWell(
                    onTap: seenByIds.isNotEmpty
                        ? () => _showSeenByList(context)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 16,
                            color: seenByIds.isNotEmpty
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "شاهده: ${seenByIds.length}",
                            style: TextStyle(
                              fontSize: 12,
                              color: seenByIds.isNotEmpty
                                  ? Colors.blue
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                              decoration: seenByIds.isNotEmpty
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                if (!canControl)
                  if (!isSeen)
                    InkWell(
                      onTap: () async => await NoticeService()
                          .markAnnouncementAsSeen(widget.notice['id']),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: priorityColor.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check, size: 16, color: Colors.white),
                            SizedBox(width: 5),
                            Text(
                              "تأكيد القراءة",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.done_all, size: 18, color: Colors.blue[300]),
                        const SizedBox(width: 5),
                        Text(
                          "تم الاطلاع",
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("هل أنت متأكد من حذف هذا الاشعار"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await NoticeService().deleteAnnouncement(id);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

Color getPriorityColor(String priority) {
  switch (priority) {
    case 'high':
      return const Color(0xFFE53935);
    case 'normal':
      return const Color(0xFF1E88E5);
    case 'low':
      return const Color(0xFF43A047);
    default:
      return Colors.grey;
  }
}

Color getPriorityBg(String priority, bool isDark) {
  if (isDark) return getPriorityColor(priority).withOpacity(0.1);
  return getPriorityColor(priority).withOpacity(0.05);
}

String getPriorityText(String priority) {
  switch (priority) {
    case 'high':
      return "high";
    case 'normal':
      return "normal";
    case 'low':
      return "low";
    default:
      return "general";
  }
}
