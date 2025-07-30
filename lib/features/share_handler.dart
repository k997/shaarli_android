import 'package:http/http.dart' as http;
import 'package:shaarli_android/api/shaarli_api.dart';
import 'dart:convert';
import 'package:share_handler/share_handler.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shaarli_android/core/config_service.dart';

class ShareHandler {
  final _configService = ConfigService();
  final _shaarliApi = ShaarliApi(ConfigService());

  Future<bool> handleShare(SharedMedia media) async {
    final text = media.content ?? '';
    final url = _extractUrl(text);

    final isPrivate = await _configService.isPrivateByDefault();
    String description = '';
    String titleOrNote = text;
    if (url != null) {
      titleOrNote = _extractTitle(text, url);

      if (titleOrNote.isEmpty) {
        final fetchedData = await fetchTitleAndDescription(url);
        titleOrNote = fetchedData['title'] ?? '';
        description = fetchedData['description'] ?? '';
      }
    }

    // If no URL is found, treat it as a note.
    final response = await _shaarliApi.postLink(
      url ?? '',
      titleOrNote,
      description,
      ['from_android'],
      isPrivate,
    );
    return response.statusCode == 201;
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
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Encoding encoding = utf8; // Default fallback
        String? charset;

        // 1. Try to get charset from HTTP headers
        final contentType = response.headers['content-type'];
        if (contentType != null) {
          final match = RegExp(r'charset=([^;\s]+)', caseSensitive: false)
              .firstMatch(contentType);
          if (match != null) {
            final extractedCharset = match.group(1)!.toLowerCase();
            if (commonEncodings.contains(extractedCharset)) {
              charset = extractedCharset;
            }
          }
        }

        // Pre-decode with a lenient UTF-8 to safely parse and find the meta tag
        final preDecodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        var document = html_parser.parse(preDecodedBody);

        // 2. If not in headers, try to get from HTML meta tags
        if (charset == null) {
          final metaElements = document.querySelectorAll('meta');
          for (final metaElement in metaElements) {
            if (metaElement.attributes.containsKey('charset')) {
              final extractedCharset =
                  metaElement.attributes['charset']!.toLowerCase();
              if (commonEncodings.contains(extractedCharset)) {
                charset = extractedCharset;
                break;
              }
            } else if (metaElement.attributes['http-equiv']
                    ?.toLowerCase() ==
                'content-type') {
              final content = metaElement.attributes['content'];
              if (content != null) {
                final match =
                    RegExp(r'charset=([^;\s]+)', caseSensitive: false)
                        .firstMatch(content);
                if (match != null) {
                  final extractedCharset = match.group(1)!.toLowerCase();
                  if (commonEncodings.contains(extractedCharset)) {
                    charset = extractedCharset;
                    break;
                  }
                }
              }
            }
          }
        }

        // 3. Get the final encoding, or fallback to UTF-8
        if (charset != null) {
          encoding = Encoding.getByName(charset) ?? utf8;
        }

        // 4. If a different encoding was found, re-decode and re-parse
        if (encoding != utf8) {
          final decodedBody = encoding.decode(
            response.bodyBytes,
          );
          document = html_parser.parse(decodedBody);
        }

        // 5. Extract title and description from the correctly parsed document
        final title = document.querySelector('title')?.text.trim() ?? '';
        final description = document
                .querySelector('meta[name="description"]')
                ?.attributes['content']
                ?.trim() ??
            '';

        return {'title': title, 'description': description};
      }
    } catch (e) {
      // Handle exceptions
    }
    return {'title': '', 'description': ''};
  }
}