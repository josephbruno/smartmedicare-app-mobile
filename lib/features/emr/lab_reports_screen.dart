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
class LabReportsScreen extends StatefulWidget {
  const LabReportsScreen({super.key, required this.petId});

  final int petId;

  @override
  State<LabReportsScreen> createState() => _LabReportsScreenState();
}

class _LabReportsScreenState extends State<LabReportsScreen> {
  late Future<List<PetLabReport>> _future;
  bool _uploading = false;

  static const _reportTypes = [
    'blood',
    'urine',
    'xray',
    'scan',
    'ultrasound',
    'biopsy',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<AppServices>().emr.listLabReports(widget.petId);
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.single.path == null || !mounted) return;

    final title = TextEditingController();
    final labName = TextEditingController();
    var reportType = 'blood';
    var reportDate = DateTime.now();

    final saved = await showAppAlertForm<bool>(
      context: context,
      title: 'Upload lab report',
      content: StatefulBuilder(
        builder: (ctx, setDialog) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDropdownButtonFormField<String>(
              value: reportType,
              decoration: appFormFieldDecoration('Report type'),
              items: _reportTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setDialog(() => reportType = v ?? 'blood'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: title,
              decoration: appFormFieldDecoration('Title *'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: labName,
              decoration: appFormFieldDecoration('Lab name'),
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
      final filePath = result.files.single.path!;
      final formData = FormData.fromMap({
        'report_type': reportType,
        'report_title': title.text.trim(),
        'report_date': reportDate.toIso8601String().substring(0, 10),
        if (labName.text.isNotEmpty) 'lab_name': labName.text.trim(),
        'file': await MultipartFile.fromFile(filePath),
      });
      await emr.uploadLabReport(widget.petId, formData);
      if (mounted) {
        AppMessenger.show(context,
          const SnackBar(content: Text('Lab report uploaded')),
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

  Future<void> _openReport(PetLabReport report) async {
    final emr = context.read<AppServices>().emr;
    final url = report.fileUrl ?? emr.labReportDownloadUrl(report.id);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _delete(PetLabReport report) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete lab report?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().emr.deleteLabReport(widget.petId, report.id);
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canUpload = context.watch<AuthSession>().hasPermission(AppPermissions.emrLabReportsUpload);

    return Scaffold(
      appBar: AppBar(title: const Text('Lab reports')),
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
        child: FutureBuilder<List<PetLabReport>>(
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
                  Center(child: Text('No lab reports')),
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
                final r = items[i];
                return Card(
                  child: InkWell(
                    onTap: () => _openReport(r),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.biotech_outlined, color: AppTheme.primary),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                color: AppTheme.danger,
                                onPressed: () => _delete(r),
                              ),
                            ],
                          ),
                          Text(r.reportTitle,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const Spacer(),
                          Text(r.reportType, style: const TextStyle(fontSize: 12)),
                          Text(r.reportDate,
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
