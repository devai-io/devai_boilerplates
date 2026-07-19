import 'package:flutter/material.dart';

import '../api.dart';
import 'editor_screen.dart';
import 'login_screen.dart';
import 'post_screen.dart';

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  List<PostSummary>? _posts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _posts = null;
      _error = null;
    });
    try {
      final posts = await widget.api.listPosts();
      if (mounted) setState(() => _posts = posts);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    _load(); // refresh after editing/logging in
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('blog'),
        actions: [
          // Rebuilds on login/logout since ApiClient is a ChangeNotifier.
          ListenableBuilder(
            listenable: widget.api,
            builder: (context, _) {
              if (!widget.api.authed) {
                return TextButton(
                  onPressed: () => _push(LoginScreen(api: widget.api)),
                  child: const Text('Log in'),
                );
              }
              return Row(
                children: [
                  IconButton(
                    tooltip: 'Write',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _push(EditorScreen(api: widget.api)),
                  ),
                  IconButton(
                    tooltip: 'Log out',
                    icon: const Icon(Icons.logout),
                    onPressed: widget.api.logout,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final posts = _posts;
    if (posts == null) return const Center(child: CircularProgressIndicator());
    if (posts.isEmpty) return const Center(child: Text('No posts yet.'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const Divider(height: 32),
        itemBuilder: (context, index) {
          final post = posts[index];
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _push(PostScreen(api: widget.api, slug: post.slug)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDate(post.publishedAt),
                    style: theme.textTheme.labelSmall!
                        .copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(post.title,
                      style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    post.excerpt,
                    style: theme.textTheme.bodyMedium!
                        .copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}
