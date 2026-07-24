import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../data/models/emr.dart';
import '../../core/widgets/app_dropdown.dart';
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.petId});

  final int petId;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late Future<List<PetDocument>> _future;
  bool _uploading = false;

  static const _docTypes = [
    'vaccination_card',
    'insurance',
    'passport',
    'certificate',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<AppServices>().emr.listDocuments(widget.petId);
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.single.path == null || !mounted) return;

    final title = TextEditingController();
    final authority = TextEditingController();
    var docType = 'other';

    final saved = await showAppAlertForm<bool>(
      context: context,
      title: 'Upload document',
      content: StatefulBuilder(
        builder: (ctx, setDialog) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDropdownButtonFormField<String>(
              value: docType,
              decoration: appFormFieldDecoration('Document type'),
              items: _docTypes
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.replaceAll('_', ' ')),
                      ))
                  .toList(),
              onChanged: (v) => setDialog(() => docType = v ?? 'other'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: title,
              decoration: appFormFieldDecoration('Title *'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: authority,
              decoration: appFormFieldDecoration('Issuing authority'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: const Text('Upload'),
        ),
      ],
    );
    if (saved != true || title.text.trim().isEmpty || !mounted) return;

    setState(() => _uploading = true);
    try {
      final emr = context.read<AppServices>().emr;
      final formData = FormData.fromMap({
        'doc_type': docType,
        'title': title.text.trim(),
        if (authority.text.isNotEmpty) 'issuing_authority': authority.text.trim(),
        'file': await MultipartFile.fromFile(result.files.single.path!),
      });
      await emr.uploadDocument(widget.petId, formData);
      if (mounted) {
        AppMessenger.show(context,
          const SnackBar(content: Text('Document uploaded')),
        );
        setState(_reload);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openDocument(PetDocument doc) async {
    final emr = context.read<AppServices>().emr;
    final url = doc.fileUrl ?? emr.documentDownloadUrl(doc.id);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _delete(PetDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete document?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().emr.deleteDocument(widget.petId, doc.id);
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canUpload = context.watch<AuthSession>().hasPermission(AppPermissions.emrDocumentsUpload);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      floatingActionButton: canUpload
          ? FloatingActionButton(
              onPressed: _uploading ? null : _upload,
              child: _uploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_file),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: FutureBuilder<List<PetDocument>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('No documents')),
                ],
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final d = items[i];
                return Card(
                  child: InkWell(
                    onTap: () => _openDocument(d),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description_outlined, color: AppTheme.primary),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                color: AppTheme.danger,
                                onPressed: () => _delete(d),
                              ),
                            ],
                          ),
                          Text(d.title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const Spacer(),
                          Text(d.docType.replaceAll('_', ' '),
                              style: const TextStyle(fontSize: 12)),
                          if (d.expiryDate != null)
                            Text('Expires ${d.expiryDate}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
