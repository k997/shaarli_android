import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:shaarli_android/api/shaarli_api.dart';
import 'package:shaarli_android/core/config_service.dart';
import 'package:shaarli_android/features/add_item_page.dart';
import 'package:shaarli_android/models/shaarli_link.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkListView extends StatelessWidget {
  final List<ShaarliLink> links;
  final ScrollController scrollController;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final void Function(ShaarliLink) onLinkDeleted;
  final void Function(String) onTagTapped;
  final _log = Logger('LinkListView');
  final ShaarliApi _shaarliApi = ShaarliApi(ConfigService());

  LinkListView({
    super.key,
    required this.links,
    required this.scrollController,
    required this.isLoading,
    required this.onRefresh,
    required this.onLinkDeleted,
    required this.onTagTapped,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        itemCount: links.length + (isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= links.length) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          final link = links[index];
          return Dismissible(
            key: Key(link.id.toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            // Delete happens inside confirmDismiss so the row snaps back
            // when the user cancels or the server rejects the delete,
            // instead of leaving a dismissed widget in the tree.
            confirmDismiss: (direction) => _confirmDelete(context, link),
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
                                        child: InkWell(
                                          onTap: () => onTagTapped(tag),
                                          child: Chip(
                                            label: Text(tag),
                                            padding: EdgeInsets.zero,
                                          ),
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
                final url = Uri.tryParse(link.url);
                if (url == null || !url.isAbsolute) {
                  _log.warning('Invalid URL: ${link.url}');
                  return;
                }
                _log.info('Launching URL: $url');
                // externalApplication so this app (registered as a browser)
                // never resolves the launch to itself.
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (e) {
                  _log.warning('Could not launch $url: $e');
                }
              },
              onLongPress: () async {
                _log.info('Long pressed on link, navigating to edit page');
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddItemPage(link: link),
                  ),
                );
                if (saved == true) {
                  onRefresh();
                }
              },
            ),
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, ShaarliLink link) async {
    // Capture the messenger before awaiting so it survives this widget
    // being rebuilt while the dialog or the request is in flight.
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this link?'),
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
    if (confirmed != true) {
      return false;
    }

    _log.info('Deleting link: ${link.id}');
    try {
      final response = await _shaarliApi.deleteLink(link.id);
      if (response.statusCode == 204) {
        _log.info('Link deleted successfully');
        onLinkDeleted(link);
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Link deleted')),
        );
        return true;
      }
      _log.warning(
          'Failed to delete link, status code: ${response.statusCode}');
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content:
                Text('Failed to delete link: ${response.statusCode}')),
      );
      return false;
    } catch (e, stackTrace) {
      _log.severe('Failed to delete link', e, stackTrace);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to delete link: $e')),
      );
      return false;
    }
  }
}
