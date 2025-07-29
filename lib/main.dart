import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:share_handler/share_handler.dart';
import 'share_handler.dart' as my;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shaarli Settings',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SettingsPage(),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final _shareHandler = my.ShareHandler();
  SharedMedia? _sharedMedia;
  bool _isPrivate = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initShareHandler();
  }

  Future<void> _initShareHandler() async {
    final handler = ShareHandler.instance;
    final media = await handler.getInitialSharedMedia();
    if (media != null) {
      setState(() {
        _sharedMedia = media;
      });
      _handleSharedMedia();
    }

    handler.sharedMediaStream.listen((SharedMedia media) {
      setState(() {
        _sharedMedia = media;
      });
      _handleSharedMedia();
    });
  }

  void _handleSharedMedia() {
    if (_sharedMedia != null) {
      _shareHandler.handleShare(_sharedMedia!).then((success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'Link saved to Shaarli!' : 'Failed to save link.')),
        );
      });
    }
  }

  Future<void> _loadSettings() async {
    final url = await _storage.read(key: 'shaarli_url');
    final token = await _storage.read(key: 'shaarli_token');
    final isPrivate = await _storage.read(key: 'is_private');
    if (url != null) {
      _urlController.text = url;
    }
    if (token != null) {
      _tokenController.text = token;
    }
    if (isPrivate != null) {
      setState(() {
        _isPrivate = isPrivate == 'true';
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      await _storage.write(key: 'shaarli_url', value: _urlController.text);
      await _storage.write(key: 'shaarli_token', value: _tokenController.text);
      await _storage.write(key: 'is_private', value: _isPrivate.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved!')),
      );
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
                  if (value == null || value.isEmpty) {
                    return 'Please enter the server URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tokenController,
                decoration: const InputDecoration(
                  labelText: 'API Secret Token',
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the API token';
                  }
                  return null;
                },
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
