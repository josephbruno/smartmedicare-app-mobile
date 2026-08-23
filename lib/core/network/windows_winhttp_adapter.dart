import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ffi/ffi.dart';

/// Dio adapter that uses Windows WinHTTP (SChannel), matching PowerShell/Edge TLS.
///
/// dart:io [HttpClient] uses BoringSSL. Imunify360/LiteSpeed flags that JA3 as a
/// bot and returns HTML 403. WinHTTP is the same stack that already reaches Laravel.
class WinHttpDioAdapter implements HttpClientAdapter {
  bool _closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) {
      throw StateError("Can't establish connection after the adapter was closed.");
    }
    if (!Platform.isWindows) {
      throw StateError('WinHttpDioAdapter is Windows-only.');
    }

    final builder = BytesBuilder();
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        builder.add(chunk);
      }
    }

    final headerMap = <String, String>{};
    options.headers.forEach((key, value) {
      if (value == null) return;
      final lower = key.toLowerCase();
      if (lower == 'content-length' || lower == 'host') return;
      headerMap[key] = value.toString();
    });
    headerMap.putIfAbsent('Accept-Encoding', () => 'identity');

    // Copy primitives only. Capturing [options] (CancelToken / progress
    // callbacks) makes Isolate.run fail immediately with a null Dio message.
    final method = options.method;
    final url = options.uri.toString();
    final connectMs = options.connectTimeout?.inMilliseconds ?? 20000;
    final receiveMs = options.receiveTimeout?.inMilliseconds ?? 20000;
    final body = builder.takeBytes();
    final headers = Map<String, String>.from(headerMap);

    final result = await Isolate.run(
      () => _winHttpRequest({
        'method': method,
        'url': url,
        'headers': headers,
        'body': body,
        'connectMs': connectMs,
        'receiveMs': receiveMs,
      }),
    );

    if (result['error'] is String) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: result['error'] as String,
      );
    }

    return ResponseBody.fromBytes(
      result['body'] as Uint8List,
      result['status'] as int,
      headers: (result['headers'] as Map).map(
        (key, value) => MapEntry(
          key.toString(),
          (value as List).map((e) => e.toString()).toList(),
        ),
      ),
      statusMessage: result['statusText'] as String?,
    );
  }

  @override
  void close({bool force = false}) {
    _closed = true;
  }
}

const _winHttpAccessTypeAutomaticProxy = 4;
const _winHttpFlagSecure = 0x00800000;
const _winHttpAddReplace = 0xA0000000;
const _winHttpQueryStatusCode = 19;
const _winHttpQueryStatusText = 20;
const _winHttpQueryRawHeadersCrlf = 22;
const _winHttpQueryFlagNumber = 0x20000000;
const _errorInsufficientBuffer = 122;

Map<String, Object?> _winHttpRequest(Map<String, Object?> args) {
  final method = args['method']! as String;
  final url = Uri.parse(args['url']! as String);
  final headers = Map<String, String>.from(args['headers']! as Map);
  final body = args['body'] as Uint8List? ?? Uint8List(0);
  final connectMs = args['connectMs'] as int? ?? 20000;
  final receiveMs = args['receiveMs'] as int? ?? 20000;

  final winhttp = DynamicLibrary.open('winhttp.dll');
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final getLastError =
      kernel32.lookupFunction<Uint32 Function(), int Function()>('GetLastError');

  final winHttpOpen = winhttp.lookupFunction<
      Pointer<Void> Function(
          Pointer<Utf16>, Uint32, Pointer<Utf16>, Pointer<Utf16>, Uint32),
      Pointer<Void> Function(
          Pointer<Utf16>, int, Pointer<Utf16>, Pointer<Utf16>, int)>('WinHttpOpen');
  final winHttpConnect = winhttp.lookupFunction<
      Pointer<Void> Function(Pointer<Void>, Pointer<Utf16>, Uint16, Uint32),
      Pointer<Void> Function(
          Pointer<Void>, Pointer<Utf16>, int, int)>('WinHttpConnect');
  final winHttpOpenRequest = winhttp.lookupFunction<
      Pointer<Void> Function(Pointer<Void>, Pointer<Utf16>, Pointer<Utf16>,
          Pointer<Utf16>, Pointer<Utf16>, Pointer<Pointer<Utf16>>, Uint32),
      Pointer<Void> Function(
          Pointer<Void>,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Pointer<Pointer<Utf16>>,
          int)>('WinHttpOpenRequest');
  final winHttpSetTimeouts = winhttp.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32, Int32, Int32),
      int Function(Pointer<Void>, int, int, int, int)>('WinHttpSetTimeouts');
  final winHttpAddRequestHeaders = winhttp.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Utf16>, Uint32, Uint32),
      int Function(Pointer<Void>, Pointer<Utf16>, int, int)>(
    'WinHttpAddRequestHeaders',
  );
  final winHttpSendRequest = winhttp.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Utf16>, Uint32, Pointer<Void>,
          Uint32, Uint32, IntPtr),
      int Function(Pointer<Void>, Pointer<Utf16>, int, Pointer<Void>, int, int,
          int)>('WinHttpSendRequest');
  final winHttpReceiveResponse = winhttp.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Void>),
      int Function(Pointer<Void>, Pointer<Void>)>('WinHttpReceiveResponse');
  final winHttpQueryHeaders = winhttp.lookupFunction<
      Int32 Function(Pointer<Void>, Uint32, Pointer<Utf16>, Pointer<Void>,
          Pointer<Uint32>, Pointer<Uint32>),
      int Function(Pointer<Void>, int, Pointer<Utf16>, Pointer<Void>,
          Pointer<Uint32>, Pointer<Uint32>)>('WinHttpQueryHeaders');
  final winHttpReadData = winhttp.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Void>, Uint32, Pointer<Uint32>),
      int Function(Pointer<Void>, Pointer<Void>, int, Pointer<Uint32>)>(
    'WinHttpReadData',
  );
  final winHttpCloseHandle = winhttp.lookupFunction<Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>('WinHttpCloseHandle');

  Pointer<Void> session = nullptr;
  Pointer<Void> connect = nullptr;
  Pointer<Void> request = nullptr;
  Pointer<Utf16>? agent;
  Pointer<Utf16>? host;
  Pointer<Utf16>? verb;
  Pointer<Utf16>? path;
  Pointer<Utf16>? headerBlock;
  Pointer<Uint8>? bodyPtr;

  String fail(String step) => '$step (WinHTTP ${getLastError()})';

  try {
    agent = 'MaranBilling/1.0'.toNativeUtf16();
    session = winHttpOpen(
      agent,
      _winHttpAccessTypeAutomaticProxy,
      nullptr,
      nullptr,
      0,
    );
    if (session == nullptr) {
      return {'error': fail('WinHttpOpen')};
    }
    winHttpSetTimeouts(session, connectMs, connectMs, receiveMs, receiveMs);

    host = url.host.toNativeUtf16();
    final port = url.hasPort ? url.port : (url.isScheme('https') ? 443 : 80);
    connect = winHttpConnect(session, host, port, 0);
    if (connect == nullptr) {
      return {'error': fail('WinHttpConnect')};
    }

    final object = StringBuffer(url.path.isEmpty ? '/' : url.path);
    if (url.hasQuery) object.write('?${url.query}');
    verb = method.toNativeUtf16();
    path = object.toString().toNativeUtf16();
    final flags = url.isScheme('https') ? _winHttpFlagSecure : 0;
    request = winHttpOpenRequest(
      connect,
      verb,
      path,
      nullptr,
      nullptr,
      nullptr,
      flags,
    );
    if (request == nullptr) {
      return {'error': fail('WinHttpOpenRequest')};
    }

    if (headers.isNotEmpty) {
      final block = headers.entries
          .map((e) => '${e.key}: ${e.value}')
          .join('\r\n');
      headerBlock = '$block\r\n'.toNativeUtf16();
      final added = winHttpAddRequestHeaders(
        request,
        headerBlock,
        0xFFFFFFFF,
        _winHttpAddReplace,
      );
      if (added == 0) {
        return {'error': fail('WinHttpAddRequestHeaders')};
      }
    }

    if (body.isNotEmpty) {
      bodyPtr = calloc<Uint8>(body.length);
      bodyPtr.asTypedList(body.length).setAll(0, body);
    }

    final sent = winHttpSendRequest(
      request,
      nullptr,
      0,
      bodyPtr?.cast() ?? nullptr,
      body.length,
      body.length,
      0,
    );
    if (sent == 0) {
      return {'error': fail('WinHttpSendRequest')};
    }
    if (winHttpReceiveResponse(request, nullptr) == 0) {
      return {'error': fail('WinHttpReceiveResponse')};
    }

    final statusBuf = calloc<Uint32>();
    final statusSize = calloc<Uint32>()..value = sizeOf<Uint32>();
    final statusOk = winHttpQueryHeaders(
      request,
      _winHttpQueryStatusCode | _winHttpQueryFlagNumber,
      nullptr,
      statusBuf.cast(),
      statusSize,
      nullptr,
    );
    if (statusOk == 0) {
      calloc.free(statusBuf);
      calloc.free(statusSize);
      return {'error': fail('WinHttpQueryHeaders status')};
    }
    final status = statusBuf.value;
    calloc.free(statusBuf);
    calloc.free(statusSize);

    String? statusText;
    final textSize = calloc<Uint32>();
    winHttpQueryHeaders(
      request,
      _winHttpQueryStatusText,
      nullptr,
      nullptr,
      textSize,
      nullptr,
    );
    if (textSize.value > 0) {
      final textBuf = calloc<Uint8>(textSize.value);
      if (winHttpQueryHeaders(
            request,
            _winHttpQueryStatusText,
            nullptr,
            textBuf.cast(),
            textSize,
            nullptr,
          ) !=
          0) {
        statusText = textBuf.cast<Utf16>().toDartString();
      }
      calloc.free(textBuf);
    }
    calloc.free(textSize);

    final headerMap = <String, List<String>>{};
    final rawSize = calloc<Uint32>();
    winHttpQueryHeaders(
      request,
      _winHttpQueryRawHeadersCrlf,
      nullptr,
      nullptr,
      rawSize,
      nullptr,
    );
    if (getLastError() == _errorInsufficientBuffer || rawSize.value > 0) {
      final rawBuf = calloc<Uint8>(rawSize.value);
      if (winHttpQueryHeaders(
            request,
            _winHttpQueryRawHeadersCrlf,
            nullptr,
            rawBuf.cast(),
            rawSize,
            nullptr,
          ) !=
          0) {
        final raw = rawBuf.cast<Utf16>().toDartString();
        for (final line in raw.split(RegExp(r'\r\n'))) {
          final idx = line.indexOf(':');
          if (idx <= 0) continue;
          final name = line.substring(0, idx).trim();
          final value = line.substring(idx + 1).trim();
          headerMap.putIfAbsent(name, () => <String>[]).add(value);
        }
      }
      calloc.free(rawBuf);
    }
    calloc.free(rawSize);

    final chunks = BytesBuilder();
    final readBuf = calloc<Uint8>(16384);
    final readCount = calloc<Uint32>();
    while (true) {
      final ok = winHttpReadData(request, readBuf.cast(), 16384, readCount);
      if (ok == 0) {
        calloc.free(readBuf);
        calloc.free(readCount);
        return {'error': fail('WinHttpReadData')};
      }
      if (readCount.value == 0) break;
      chunks.add(Uint8List.fromList(readBuf.asTypedList(readCount.value)));
    }
    calloc.free(readBuf);
    calloc.free(readCount);

    return {
      'status': status,
      'statusText': statusText,
      'headers': headerMap,
      'body': chunks.takeBytes(),
    };
  } finally {
    if (request != nullptr) winHttpCloseHandle(request);
    if (connect != nullptr) winHttpCloseHandle(connect);
    if (session != nullptr) winHttpCloseHandle(session);
    if (agent != null) calloc.free(agent);
    if (host != null) calloc.free(host);
    if (verb != null) calloc.free(verb);
    if (path != null) calloc.free(path);
    if (headerBlock != null) calloc.free(headerBlock);
    if (bodyPtr != null) calloc.free(bodyPtr);
  }
}
