import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';
import 'package:shaarli_android/api/shaarli_api.dart';
import 'package:shaarli_android/core/config_service.dart';
import 'package:shaarli_android/features/add_item_page.dart';
import 'package:shaarli_android/features/settings_page.dart';
import 'package:shaarli_android/features/share_handler.dart' as my;
import 'package:shaarli_android/models/shaarli_link.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final _shareHandler = my.ShareHandler();
  SharedMedia? _sharedMedia;

  final _shaarliApi = ShaarliApi(ConfigService());
  final _links = <ShaarliLink>[];
  bool _isLoading = false;
  int _offset = 0;
  final int _limit = 10;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initShareHandler();
    _fetchLinks();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _fetchLinks();
      }
    });
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
              content: Text(
                success ? 'Link saved to Shaarli!' : 'Failed to save link.',
              ),
            ),
          );
        }
      });
    }
  }

  Future<void> _fetchLinks() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final newLinks = await _shaarliApi.getLinks(
        limit: _limit,
        offset: _offset,
      );
      
      if (mounted) {
        setState(() {
          _links.addAll(newLinks);
          _offset += _limit;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load links: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    _offset = 0;
    _links.clear();
    await _fetchLinks();
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _links.length + (_isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            final link = _links[index];
            return Dismissible(
              key: Key(link.id.toString()),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Confirm Delete'),
                      content: const Text(
                          'Are you sure you want to delete this link?'),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    );
                  },
                );
              },
              onDismissed: (direction) async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                try {
                  final response = await _shaarliApi.deleteLink(link.id);
                  if (response.statusCode == 204) {
                    setState(() {
                      _links.removeAt(index);
                    });
                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Link deleted')),
                    );
                  } else {
                    await _refresh();
                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                          content: Text(
                              'Failed to delete link: ${response.statusCode}')),
                    );
                  }
                } catch (e) {
                  await _refresh();
                  if (!mounted) return;
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Failed to delete link: $e')),
                  );
                }
              },
            child: ListTile(
              tileColor: index.isEven ? Colors.grey.shade100 : null,
                title: Text(
                  link.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 32, // Reserve space for tags
                      child: link.tags.isNotEmpty
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: link.tags
                                    .map((tag) => Padding(
                                          padding: const EdgeInsets.only(right: 4.0),
                                          child: Chip(
                                            label: Text(tag),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ))
                                    .toList(),
                              ),
                            )
                          : null, // Render nothing if no tags
                    )
                  ],
                ),
                onTap: () async {
                  final url = Uri.parse(link.url);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                onLongPress: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddItemPage(link: link),
                    ),
                  );
                  if (result == true) {
                    _refresh();
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
