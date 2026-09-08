import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:shaarli_android/api/shaarli_api.dart';
import 'package:shaarli_android/core/config_service.dart';
import 'package:shaarli_android/features/share_handler.dart' as my;
import 'package:shaarli_android/models/shaarli_link.dart';

class AddItemPage extends StatefulWidget {
  final ShaarliLink? link;

  /// URL to prefill for a new item, e.g. one captured through the app's
  /// "browser" role.
  final String? initialUrl;

  const AddItemPage({super.key, this.link, this.initialUrl});

  @override
  AddItemPageState createState() => AddItemPageState();
}

class AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isPrivate = true;
  bool _isSaving = false;
  Timer? _debounce;

  final _shareHandler = my.ShareHandler();
  final _configService = ConfigService();
  final _shaarliApi = ShaarliApi(ConfigService());
  final _log = Logger('AddItemPage');

  @override
  void initState() {
    super.initState();
    _log.info('Initializing AddItemPage');
    final link = widget.link;
    if (link != null) {
      _log.info('Editing link: ${link.id}');
      _urlController.text = link.url;
      _titleController.text = link.title;
      _descriptionController.text = link.description;
      _tagsController.text = link.tags.join(' ');
      _isPrivate = link.private;
    } else {
      _log.info('Adding new item');
      if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
        _urlController.text = widget.initialUrl!;
      }
      // Only apply the default privacy to new items; when editing, the
      // link's own value must win over the global default.
      _configService.isPrivateByDefault().then((isPrivate) {
        if (mounted) {
          setState(() {
            _isPrivate = isPrivate;
          });
        }
      });
    }
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _log.info('Disposing AddItemPage');
    _debounce?.cancel();
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      if (_urlController.text.isNotEmpty) {
        _log.info('URL changed, fetching metadata');
        _fetchUrlMetadata();
      }
    });
  }

  void _fetchUrlMetadata() async {
    final url = _urlController.text.trim();
    if (url.isNotEmpty && Uri.tryParse(url)?.isAbsolute == true) {
      _log.info('Fetching metadata for URL: $url');
      if (_titleController.text.trim().isEmpty ||
          _descriptionController.text.trim().isEmpty) {
        try {
          final fetchedData = await _shareHandler.fetchTitleAndDescription(url);
          if (mounted) {
            setState(() {
              if (_titleController.text.trim().isEmpty) {
                _titleController.text = fetchedData['title'] ?? '';
              }
              if (_descriptionController.text.trim().isEmpty) {
                _descriptionController.text = fetchedData['description'] ?? '';
              }
            });
          }
        } catch (e, stackTrace) {
          _log.severe('Failed to fetch URL metadata', e, stackTrace);
        }
      }
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    _log.info('Saving item');
    setState(() {
      _isSaving = true;
    });

    try {
      final shaarliUrl = await _configService.getApiUrl();
      final jwt = await _configService.getJwtToken();
      if (shaarliUrl == null || jwt == null) {
        _log.warning('Shaarli settings not configured');
        throw const ShaarliException(
          'Please configure Shaarli settings first.',
        );
      }

      final url = _urlController.text.trim();
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final tags = _tagsController.text
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();

      final response = widget.link != null
          ? await _shaarliApi.updateLink(
              widget.link!.id,
              url,
              title,
              description,
              tags,
              _isPrivate,
            )
          : await _shaarliApi.postLink(
              url,
              title,
              description,
              tags,
              _isPrivate,
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _log.info('Item saved successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Item ${widget.link != null ? 'updated' : 'saved'} successfully!')),
          );
          Navigator.pop(context, true);
        }
        return;
      }

      _log.warning(
          'Failed to save item, status code: ${response.statusCode}');
      _showError('Failed to save item (HTTP ${response.statusCode}).');
    } on ShaarliException catch (e) {
      _showError(e.message);
    } catch (e, stackTrace) {
      _log.severe('Failed to save item', e, stackTrace);
      _showError('Failed to save item.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.link != null ? 'Edit Item' : 'Add Item')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'URL'),
                validator: (value) {
                  final url = value?.trim();
                  if (url != null &&
                      url.isNotEmpty &&
                      Uri.tryParse(url)?.isAbsolute != true) {
                    return 'Please enter a valid URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (_urlController.text.trim().isEmpty &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Please enter a title for the note';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (space-separated)',
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Private link'),
                value: _isPrivate,
                onChanged: (value) {
                  setState(() {
                    _isPrivate = value;
                  });
                },
              ),
              const SizedBox(height: 32),
              _isSaving
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _saveItem,
                      child: const Text('Save'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
