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
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // Explicitly decode the body as UTF-8 to handle encoding issues.
        final decodedBody = utf8.decode(
          response.bodyBytes,
          allowMalformed: true,
        );
        final document = html_parser.parse(decodedBody);
        final title = document.querySelector('title')?.text ?? '';
        final description =
            document
                .querySelector('meta[name="description"]')
                ?.attributes['content'] ??
            '';
        return {'title': title, 'description': description};
      }
    } catch (e) {
      // Handle exceptions
    }
    return {'title': '', 'description': ''};
  }
}
