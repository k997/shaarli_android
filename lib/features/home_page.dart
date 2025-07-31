import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';
import 'package:shaarli_android/api/shaarli_api.dart';
import 'package:shaarli_android/core/config_service.dart';
import 'package:shaarli_android/features/add_item_page.dart';
import 'package:shaarli_android/features/settings_page.dart';
import 'package:shaarli_android/features/share_handler.dart' as my;
import 'package:shaarli_android/models/shaarli_link.dart';
import 'package:shaarli_android/features/link_list_view.dart';
import 'package:logging/logging.dart';

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
  String _searchQuery = '';
  String _searchTags = '';
  String _visibility = 'all';
  final _scrollController = ScrollController();
  final _log = Logger('HomePage');

  @override
  void initState() {
    super.initState();
    _log.info('Initializing HomePage');
    _initShareHandler();
    _fetchLinks();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _log.info('Scrolled to bottom, fetching more links');
        _fetchLinks();
      }
    });
  }

  Future<void> _initShareHandler() async {
    _log.info('Initializing ShareHandler');
    final handler = ShareHandler.instance;
    final media = await handler.getInitialSharedMedia();
    if (media != null) {
      _log.info('Initial shared media found');
      setState(() {
        _sharedMedia = media;
      });
      _handleSharedMedia();
    }

    handler.sharedMediaStream.listen((SharedMedia media) {
      _log.info('Received shared media stream');
      setState(() {
        _sharedMedia = media;
      });
      _handleSharedMedia();
    });
  }

  void _handleSharedMedia() {
    if (_sharedMedia != null) {
      _log.info('Handling shared media');
      _shareHandler.handleShare(_sharedMedia!).then((success) {
        if (mounted) {
          _log.info('Share handled, success: $success');
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

  Future<void> _fetchLinks({
    String? searchQuery,
    String? searchTags,
    String? visibility,
  }) async {
    if (_isLoading) return;
    _log.info('Fetching links');
    setState(() {
      _isLoading = true;
    });

    try {
      final newLinks = await _shaarliApi.getLinks(
        limit: _limit,
        offset: _offset,
        search: searchQuery,
        searchTags: searchTags,
        visibility: visibility,
      );
      _log.info('Fetched ${newLinks.length} new links');

      if (mounted) {
        setState(() {
          _links.addAll(newLinks);
          _offset += _limit;
        });
      }
    } catch (e, stackTrace) {
      _log.severe('Failed to load links', e, stackTrace);
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
    _log.info('Refreshing links');
    setState(() {
      _offset = 0;
      _links.clear();
    });
    await _fetchLinks(
      searchQuery: _searchQuery,
      searchTags: _searchTags,
      visibility: _visibility,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            if (_searchQuery.isNotEmpty ||
                _searchTags.isNotEmpty ||
                _visibility != 'all') {
              setState(() {
                _searchQuery = '';
                _searchTags = '';
                _visibility = 'all';
              });
              _refresh();
            } else {
              _scrollController.animateTo(
                0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
          child: const Text('Shaarli'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              _log.info('Search button pressed');
              final searchParams = await showSearch<Map<String, String>>(
                context: context,
                delegate: LinkSearchDelegate(),
              );
              if (searchParams != null) {
                setState(() {
                  _searchQuery = searchParams['query'] ?? '';
                  _searchTags = searchParams['tags'] ?? '';
                  _visibility = searchParams['visibility'] ?? 'all';
                });
                _refresh();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _log.info('Navigating to AddItemPage');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddItemPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _log.info('Navigating to SettingsPage');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: LinkListView(
        links: _links,
        scrollController: _scrollController,
        isLoading: _isLoading,
        onRefresh: _refresh,
        onLinkDeleted: (link) {
          setState(() {
            _links.remove(link);
          });
        },
        onTagTapped: (tag) {
          setState(() {
            _searchTags = tag;
          });
          _refresh();
        },
      ),
    );
  }
}

class LinkSearchDelegate extends SearchDelegate<Map<String, String>> {

  String _searchTags = '';
  String _visibility = 'all';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.filter_list),
        onPressed: () {
          _showFilterDialog(context);
        },
      ),
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Search'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Tags (space-separated)'),
                onChanged: (value) {
                  _searchTags = value.replaceAll(' ', '+');
                },
              ),
              DropdownButtonFormField<String>(
                value: _visibility,
                decoration: const InputDecoration(labelText: 'Visibility'),
                items: ['all', 'public', 'private'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    _visibility = newValue;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, {});
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final searchParams = {
      'query': query,
      'tags': _searchTags,
      'visibility': _visibility,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      close(context, searchParams);
    });
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container();
  }
}
