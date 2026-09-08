import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:share_handler/share_handler.dart';
import 'package:shaarli_android/api/shaarli_api.dart';
import 'package:shaarli_android/core/config_service.dart';
import 'package:shaarli_android/features/add_item_page.dart';
import 'package:shaarli_android/features/link_list_view.dart';
import 'package:shaarli_android/features/settings_page.dart';
import 'package:shaarli_android/features/share_handler.dart' as my;
import 'package:shaarli_android/models/shaarli_link.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final _shareHandler = my.ShareHandler();
  final _shaarliApi = ShaarliApi(ConfigService());
  final _appLinks = AppLinks();
  final _links = <ShaarliLink>[];
  final _scrollController = ScrollController();
  final _log = Logger('HomePage');

  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 10;

  // Incremented on every refresh so responses of stale page loads can be
  // discarded instead of being appended to a cleared list.
  int _requestSeq = 0;

  String _searchQuery = '';
  String _searchTags = '';
  String _visibility = 'all';

  StreamSubscription<SharedMedia>? _shareSubscription;
  StreamSubscription<Uri>? _appLinkSubscription;

  @override
  void initState() {
    super.initState();
    _log.info('Initializing HomePage');
    _initShareHandler();
    _initAppLinks();
    _fetchLinks();
    _scrollController.addListener(() {
      if (!_hasMore || _isLoading) return;
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _log.info('Scrolled near bottom, fetching more links');
        _fetchLinks();
      }
    });
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    _appLinkSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initShareHandler() async {
    _log.info('Initializing ShareHandler');
    try {
      final handler = ShareHandler.instance;
      final media = await handler.getInitialSharedMedia();
      if (media != null && mounted) {
        _log.info('Initial shared media found');
        _handleSharedMedia(media);
      }
      _shareSubscription = handler.sharedMediaStream.listen(
        (media) {
          if (!mounted) return;
          _log.info('Received shared media stream');
          _handleSharedMedia(media);
        },
        onError: (e) => _log.warning('Share media stream error: $e'),
      );
    } catch (e, stackTrace) {
      _log.severe('Failed to initialize ShareHandler', e, stackTrace);
    }
  }

  /// Handles URLs captured through the app's "browser" role (ACTION_VIEW
  /// http/https intents): opens the add form prefilled with the URL.
  Future<void> _initAppLinks() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null && mounted) {
        _openCapturedUrl(initialLink.toString());
      }
      _appLinkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          if (!mounted) return;
          _openCapturedUrl(uri.toString());
        },
        onError: (e) => _log.warning('App link stream error: $e'),
      );
    } catch (e, stackTrace) {
      _log.severe('Failed to initialize app links', e, stackTrace);
    }
  }

  Future<void> _openCapturedUrl(String url) async {
    _log.info('Opening captured URL: $url');
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => AddItemPage(initialUrl: url)),
    );
    if (saved == true) {
      await _refresh();
    }
  }

  Future<void> _handleSharedMedia(SharedMedia media) async {
    _log.info('Handling shared media');
    final success = await _shareHandler.handleShare(media);
    _log.info('Share handled, success: $success');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Link saved to Shaarli!' : 'Failed to save link.',
        ),
      ),
    );
    if (success) {
      await _refresh();
    }
  }

  Future<void> _fetchLinks() async {
    if (_isLoading || !_hasMore) return;
    _requestSeq += 1;
    final seq = _requestSeq;
    _log.info('Fetching links (offset $_offset)');
    setState(() {
      _isLoading = true;
    });

    try {
      final newLinks = await _shaarliApi.getLinks(
        limit: _limit,
        offset: _offset,
        search: _searchQuery,
        searchTags: _searchTags,
        visibility: _visibility,
      );
      _log.info('Fetched ${newLinks.length} new links');

      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _links.addAll(newLinks);
        _offset += _limit;
        if (newLinks.length < _limit) {
          _hasMore = false;
        }
      });
    } catch (e, stackTrace) {
      _log.severe('Failed to load links', e, stackTrace);
      if (!mounted || seq != _requestSeq) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load links: $e')));
    } finally {
      if (mounted && seq == _requestSeq) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    _log.info('Refreshing links');
    _requestSeq += 1;
    setState(() {
      _offset = 0;
      _hasMore = true;
      _isLoading = false;
      _links.clear();
    });
    await _fetchLinks();
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
              if (searchParams != null && mounted) {
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
            onPressed: () async {
              _log.info('Navigating to AddItemPage');
              final saved = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (context) => const AddItemPage()),
              );
              if (saved == true) {
                await _refresh();
              }
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
                  _searchTags = value.trim().replaceAll(RegExp(r'\s+'), '+');
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
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
