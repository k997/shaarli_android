import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:shaarli_android/core/config_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _tagsController = TextEditingController();
  final _configService = ConfigService();
  bool _isPrivate = true;
  bool _hasStoredToken = false;
  final _log = Logger('SettingsPage');

  @override
  void initState() {
    super.initState();
    _log.info('Initializing SettingsPage');
    _loadSettings();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    _log.info('Loading settings');
    try {
      final url = await _configService.getApiUrl();
      final isPrivate = await _configService.isPrivateByDefault();
      final tags = await _configService.getTags();
      final hasToken = await _configService.hasApiSecret();
      if (!mounted) return;
      setState(() {
        if (url != null) {
          _urlController.text = url;
        }
        if (tags != null) {
          _tagsController.text = tags;
        }
        _isPrivate = isPrivate;
        _hasStoredToken = hasToken;
      });
      _log.info('Settings loaded successfully');
    } catch (e, stackTrace) {
      _log.severe('Failed to load settings', e, stackTrace);
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      _log.info('Saving settings');
      try {
        await _configService.saveSettings(
          _urlController.text,
          _tokenController.text,
          _isPrivate,
          _tagsController.text,
        );
        _log.info('Settings saved successfully');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved!')),
        );
      } catch (e, stackTrace) {
        _log.severe('Failed to save settings', e, stackTrace);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save settings.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shaarli Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Shaarli Server URL',
                  hintText: 'https://myshaarli.domain.com',
                ),
                validator: (value) {
                  final url = value?.trim();
                  if (url == null || url.isEmpty) {
                    return 'Please enter the server URL';
                  }
                  final uri = Uri.tryParse(url);
                  if (uri == null ||
                      !uri.isAbsolute ||
                      (uri.scheme != 'http' && uri.scheme != 'https')) {
                    return 'Please enter a valid http(s) URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tokenController,
                decoration: InputDecoration(
                  labelText: 'API Secret Token',
                  helperText: _hasStoredToken
                      ? 'Leave empty to keep the saved token'
                      : null,
                ),
                obscureText: true,
                validator: (value) {
                  if ((value == null || value.isEmpty) && !_hasStoredToken) {
                    return 'Please enter the API token';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Default Tags',
                  hintText: 'e.g. from_android mobile',
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
              ElevatedButton(
                onPressed: _saveSettings,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
