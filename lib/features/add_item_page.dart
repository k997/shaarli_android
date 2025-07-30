import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shaarli_android/api/shaarli_api.dart';
import 'package:shaarli_android/core/config_service.dart';
import 'package:shaarli_android/features/share_handler.dart' as my;

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

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

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    _configService.isPrivateByDefault().then((isPrivate) {
      setState(() {
        _isPrivate = isPrivate;
      });
    });
  }

  @override
  void dispose() {
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
        _fetchUrlMetadata();
      }
    });
  }

  void _fetchUrlMetadata() async {
    final url = _urlController.text.trim();
    if (url.isNotEmpty && Uri.tryParse(url)?.isAbsolute == true) {
      if (_titleController.text.trim().isEmpty ||
          _descriptionController.text.trim().isEmpty) {
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
      }
    }
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final shaarliUrl = await _configService.getApiUrl();
      final jwt = await _configService.getJwtToken();

      if (shaarliUrl == null || jwt == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please configure Shaarli settings first.'),
          ),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final url = _urlController.text.trim();
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final tags = _tagsController.text
          .split(' ')
          .where((s) => s.isNotEmpty)
          .toList();

      final response = await _shaarliApi.postLink(
        url,
        title,
        description,
        tags,
        _isPrivate,
      );

      if (mounted) {
        if (response.statusCode == 201) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item saved successfully!')),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Failed to save item.')));
        }
      }

      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Item')),
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
