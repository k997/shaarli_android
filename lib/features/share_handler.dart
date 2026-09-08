import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:shaarli_android/api/shaarli_api.dart';
import 'package:shaarli_android/core/config_service.dart';
import 'package:share_handler/share_handler.dart';

class ShareHandler {
  final _configService = ConfigService();
  final _shaarliApi = ShaarliApi(ConfigService());
  final _log = Logger('ShareHandler');

  static const _fetchTimeout = Duration(seconds: 10);

  Future<bool> handleShare(SharedMedia media) async {
    _log.info('Handling share');
    final text = media.content ?? '';
    final url = _extractUrl(text);

    final isPrivate = await _configService.isPrivateByDefault();
    String description = '';
    String titleOrNote = text;
    if (url != null) {
      _log.info('URL extracted: $url');
      titleOrNote = _extractTitle(text, url);

      if (titleOrNote.isEmpty) {
        _log.info('Title is empty, fetching from URL');
        final fetchedData = await fetchTitleAndDescription(url);
        titleOrNote = fetchedData['title'] ?? '';
        description = fetchedData['description'] ?? '';
      }
    } else {
      _log.info('No URL found, treating as a note');
    }

    final tags = await _configService.getTags();
    final tagsList = tags
        ?.split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList() ?? const <String>[];

    // If no URL is found, treat it as a note.
    final response = await _shaarliApi.postLink(
      url ?? '',
      titleOrNote,
      description,
      tagsList,
      isPrivate,
    );
    if (response.statusCode == 201) {
      _log.info('Link posted successfully');
      return true;
    } else {
      _log.warning(
          'Failed to post link, status code: ${response.statusCode}');
      return false;
    }
  }

  String? _extractUrl(String text) {
    final urlRegex = RegExp(
      r'https?://[\w-]+(\.[\w-]+)+([\w.,@?^=%&:/~+#-]*[\w@?^=%&/~+#-])?',
    );
    final match = urlRegex.firstMatch(text);
    return match?.group(0);
  }

  String _extractTitle(String text, String url) {
    final title = text.replaceAll(url, '').trim();
    return title.isNotEmpty ? title : '';
  }

  Future<Map<String, String>> fetchTitleAndDescription(String url) async {
    _log.info('Fetching title and description for: $url');
    // Charsets found on the web that the platform's ICU converter can handle.
    // utf-8 and latin-1 are decoded natively by Dart.
    const commonEncodings = {
      'utf-8',
      'iso-8859-1',
      'windows-1252',
      'gb2312',
      'gbk',
      'big5',
      'shift_jis',
      'euc-jp',
      'euc-kr',
      'windows-1251',
    };

    try {
      final response = await http.get(Uri.parse(url)).timeout(_fetchTimeout);
      if (response.statusCode == 200) {
        _log.info('Successfully fetched URL, status code: 200');
        String? charset;

        // Pre-decode with a lenient UTF-8 to safely parse and find the meta
        // tag; charset names are ASCII so this is safe for detection.
        final preDecodedBody =
            utf8.decode(response.bodyBytes, allowMalformed: true);
        var document = html_parser.parse(preDecodedBody);

        // 1. Try to get charset from HTTP headers
        final contentType = response.headers['content-type'];
        if (contentType != null) {
          final match = RegExp(r'charset=([^;\s]+)', caseSensitive: false)
              .firstMatch(contentType);
          if (match != null) {
            final extractedCharset = match.group(1)!.toLowerCase();
            if (commonEncodings.contains(extractedCharset)) {
              charset = extractedCharset;
              _log.info('Charset from headers: $charset');
            }
          }
        }

        // 2. If not in headers, try to get from HTML meta tags
        charset ??= _charsetFromMetaTags(document, commonEncodings);

        // 3. If a non-UTF-8 charset was found, re-decode and re-parse
        if (charset != null && charset != 'utf-8') {
          _log.info('Re-decoding with $charset');
          final decodedBody = await _decode(charset, response.bodyBytes);
          if (decodedBody != null) {
            document = html_parser.parse(decodedBody);
          }
        }

        // 4. Extract title and description from the parsed document
        final title = document.querySelector('title')?.text.trim() ?? '';
        final description = document
                .querySelector('meta[name="description"]')
                ?.attributes['content']
                ?.trim() ??
            '';
        _log.info('Title: $title');
        _log.info('Description: $description');

        return {'title': title, 'description': description};
      } else {
        _log.warning(
            'Failed to fetch URL, status code: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _log.severe('Error fetching title and description', e, stackTrace);
    }
    return {'title': '', 'description': ''};
  }

  String? _charsetFromMetaTags(
    html.Document document,
    Set<String> commonEncodings,
  ) {
    final metaElements = document.querySelectorAll('meta');
    for (final metaElement in metaElements) {
      if (metaElement.attributes.containsKey('charset')) {
        final extractedCharset =
            metaElement.attributes['charset']!.toLowerCase();
        if (commonEncodings.contains(extractedCharset)) {
          _log.info('Charset from meta tag: $extractedCharset');
          return extractedCharset;
        }
      } else if (metaElement.attributes['http-equiv']?.toLowerCase() ==
          'content-type') {
        final content = metaElement.attributes['content'];
        if (content != null) {
          final match =
              RegExp(r'charset=([^;\s]+)', caseSensitive: false)
                  .firstMatch(content);
          if (match != null) {
            final extractedCharset = match.group(1)!.toLowerCase();
            if (commonEncodings.contains(extractedCharset)) {
              _log.info('Charset from meta tag: $extractedCharset');
              return extractedCharset;
            }
          }
        }
      }
    }
    return null;
  }

  /// Decodes bytes with the given charset via the platform's converter,
  /// falling back to lenient UTF-8 when the charset is unsupported
  /// (Dart's dart:convert only knows utf-8, latin-1 and ascii).
  Future<String?> _decode(String charset, Uint8List bytes) async {
    if (charset == 'iso-8859-1') {
      return latin1.decode(bytes, allowInvalid: true);
    }
    try {
      return await CharsetConverter.decode(charset, bytes);
    } catch (e, stackTrace) {
      _log.warning('Decoding with $charset failed, keeping UTF-8', e, stackTrace);
      return null;
    }
  }
}
