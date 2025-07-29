import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';
import 'package:shaarli_android/add_item_page.dart';
import 'package:shaarli_android/settings_page.dart';
import 'package:shaarli_android/share_handler.dart' as my;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _shareHandler = my.ShareHandler();
  SharedMedia? _sharedMedia;

  @override
  void initState() {
    super.initState();
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(success
                    ? 'Link saved to Shaarli!'
                    : 'Failed to save link.')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shaarli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddItemPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Welcome to Shaarli!'),
      ),
    );
  }
}
