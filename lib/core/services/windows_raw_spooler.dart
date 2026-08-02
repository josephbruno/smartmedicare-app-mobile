import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// WinSpool / UNC RAW helpers (no Flutter engine required).
class WindowsRawSpooler {
  WindowsRawSpooler._();

  static Future<List<String>> listPrinters() async {
    if (!Platform.isWindows) return const [];
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Get-Printer | Select-Object -ExpandProperty Name',
      ]);
      if (result.exitCode != 0) return const [];
      return const LineSplitter()
          .convert('${result.stdout}')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<int> jobCount(String printerName) async {
    if (!Platform.isWindows) return 0;
    final name = printerName.trim().replaceAll("'", "''");
    if (name.isEmpty) return 0;
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "(Get-PrintJob -PrinterName '$name' -ErrorAction SilentlyContinue | Measure-Object).Count",
      ]);
      if (result.exitCode != 0) return 0;
      return int.tryParse('${result.stdout}'.trim()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Cancels only zero-size / retained ghosts that block the USB port.
  static Future<void> cancelStuckJobs(String printerName) async {
    if (!Platform.isWindows) return;
    final name = printerName.trim().replaceAll("'", "''");
    if (name.isEmpty) return;
    try {
      await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        """
Get-PrintJob -PrinterName '$name' -ErrorAction SilentlyContinue |
  Where-Object { \$_.Size -eq 0 -or "\$(\$_.JobStatus)" -match 'Retained|Error|Deleting' } |
  Remove-PrintJob -Confirm:\$false -ErrorAction SilentlyContinue
""",
      ]);
    } catch (_) {}
  }

  /// Sends TSPL bytes. Prefers `copy /b` to a local share (reliable RAW),
  /// then WinSpool. Returns true only if the queue clears with a non-zero job.
  static Future<bool> printRaw({
    required String printerName,
    required Uint8List data,
    bool verifyCleared = true,
  }) async {
    if (!Platform.isWindows) return false;
    final name = printerName.trim();
    if (name.isEmpty || data.isEmpty) return false;

    await cancelStuckJobs(name);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final tmpDir = Directory.systemTemp;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final binFile = File('${tmpDir.path}${Platform.pathSeparator}maran_tspl_$stamp.bin');
    await binFile.writeAsBytes(data, flush: true);

    try {
      // 1) copy /b → \\localhost\<share> (true RAW passthrough)
      if (await _printViaCopyShare(name, binFile)) {
        if (!verifyCleared) return true;
        if (await _waitForClear(name)) return true;
      }

      // 2) WinSpool RAW with correct DOC_INFO marshaling
      if (await _printViaWinSpool(name, binFile)) {
        if (!verifyCleared) return true;
        if (await _waitForClear(name)) return true;
      }

      await cancelStuckJobs(name);
      return false;
    } finally {
      try {
        if (await binFile.exists()) await binFile.delete();
      } catch (_) {}
    }
  }

  static Future<bool> _waitForClear(String printerName) async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (await jobCount(printerName) == 0) return true;
    }
    return false;
  }

  static Future<bool> _printViaCopyShare(String printerName, File binFile) async {
    final share = await _ensureShare(printerName);
    if (share == null) return false;
    try {
      final unc = '\\\\localhost\\$share';
      final result = await Process.run(
        'cmd',
        ['/c', 'copy', '/b', binFile.path, unc],
        runInShell: false,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Ensures the printer is shared; returns share name or null.
  static Future<String?> _ensureShare(String printerName) async {
    final escaped = printerName.replaceAll("'", "''");
    try {
      final existing = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        """
\$p = Get-Printer -Name '$escaped' -ErrorAction Stop
if (\$p.ShareName) { \$p.ShareName; exit 0 }
\$share = 'MaranTsplRaw'
Set-Printer -Name '$escaped' -Shared \$true -ShareName \$share -ErrorAction Stop
\$share
""",
      ]);
      if (existing.exitCode != 0) return null;
      final share = '${existing.stdout}'.trim().split(RegExp(r'\s+')).last;
      return share.isEmpty ? null : share;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _printViaWinSpool(String printerName, File binFile) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final psFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}maran_tspl_$stamp.ps1',
    );
    final binPath = binFile.path.replaceAll("'", "''");
    final printer = printerName.replaceAll("'", "''");

    // Classic RawPrinterHelper: StartDocPrinter returns job id (DWORD), not bool.
    final script = '''
\$ErrorActionPreference = 'Stop'
Add-Type @"
using System;
using System.IO;
using System.Runtime.InteropServices;
public class MaranRawHelper {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
  public class DOCINFOA {
    [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
    [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
  }
  [DllImport("winspool.drv", EntryPoint = "OpenPrinterA", SetLastError = true, CharSet = CharSet.Ansi, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool OpenPrinter([MarshalAs(UnmanagedType.LPStr)] string szPrinter, out IntPtr hPrinter, IntPtr pd);
  [DllImport("winspool.drv", EntryPoint = "ClosePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool ClosePrinter(IntPtr hPrinter);
  [DllImport("winspool.drv", EntryPoint = "StartDocPrinterA", SetLastError = true, CharSet = CharSet.Ansi, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern int StartDocPrinter(IntPtr hPrinter, int level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);
  [DllImport("winspool.drv", EntryPoint = "EndDocPrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool EndDocPrinter(IntPtr hPrinter);
  [DllImport("winspool.drv", EntryPoint = "StartPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool StartPagePrinter(IntPtr hPrinter);
  [DllImport("winspool.drv", EntryPoint = "EndPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool EndPagePrinter(IntPtr hPrinter);
  [DllImport("winspool.drv", EntryPoint = "WritePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, int dwCount, out int dwWritten);
  public static bool SendBytes(string printerName, byte[] bytes) {
    IntPtr hPrinter = IntPtr.Zero;
    if (!OpenPrinter(printerName.Normalize(), out hPrinter, IntPtr.Zero)) return false;
    var di = new DOCINFOA();
    di.pDocName = "Maran TSPL";
    di.pOutputFile = null;
    di.pDataType = "RAW";
    if (StartDocPrinter(hPrinter, 1, di) == 0) { ClosePrinter(hPrinter); return false; }
    if (!StartPagePrinter(hPrinter)) { EndDocPrinter(hPrinter); ClosePrinter(hPrinter); return false; }
    IntPtr p = Marshal.AllocCoTaskMem(bytes.Length);
    Marshal.Copy(bytes, 0, p, bytes.Length);
    int written = 0;
    bool ok = WritePrinter(hPrinter, p, bytes.Length, out written);
    Marshal.FreeCoTaskMem(p);
    EndPagePrinter(hPrinter);
    EndDocPrinter(hPrinter);
    ClosePrinter(hPrinter);
    return ok && written == bytes.Length;
  }
  public static bool SendFile(string printerName, string path) {
    return SendBytes(printerName, File.ReadAllBytes(path));
  }
}
"@
if (-not [MaranRawHelper]::SendFile('$printer', '$binPath')) { exit 1 }
exit 0
''';

    try {
      await psFile.writeAsString(script, flush: true);
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', psFile.path],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    } finally {
      try {
        if (await psFile.exists()) await psFile.delete();
      } catch (_) {}
    }
  }
}
