class UpdatePackageInfo {
  const UpdatePackageInfo({
    required this.url,
    required this.sha256,
    required this.sizeBytes,
  });

  final String url;
  final String sha256;
  final int sizeBytes;

  factory UpdatePackageInfo.fromJson(Map<String, dynamic> j) {
    return UpdatePackageInfo(
      url: j['url']?.toString() ?? '',
      sha256: j['sha256']?.toString() ?? '',
      sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.updateAvailable,
    this.mandatory = false,
    this.version,
    this.buildNumber,
    this.releaseNotes,
    this.package,
  });

  final bool updateAvailable;
  final bool mandatory;
  final String? version;
  final int? buildNumber;
  final String? releaseNotes;
  final UpdatePackageInfo? package;

  factory UpdateCheckResult.fromJson(Map<String, dynamic> j) {
    final packageJson = j['package'];
    return UpdateCheckResult(
      updateAvailable: j['update_available'] == true,
      mandatory: j['mandatory'] == true,
      version: j['version']?.toString(),
      buildNumber: (j['build_number'] as num?)?.toInt(),
      releaseNotes: j['release_notes']?.toString(),
      package: packageJson is Map<String, dynamic>
          ? UpdatePackageInfo.fromJson(packageJson)
          : null,
    );
  }
}

class UpdateException implements Exception {
  UpdateException(this.message);
  final String message;

  @override
  String toString() => message;
}
