import 'package:flutter/material.dart';

import '../api.dart';
import '../markdown.dart';
import 'editor_screen.dart';
import 'posts_screen.dart' show formatDate;

class PostScreen extends StatefulWidget {
  const PostScreen({super.key, required this.api, required this.slug});

  final ApiClient api;
  final String slug;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  Post? _post;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final post = await widget.api.getPost(_post?.slug ?? widget.slug);
      if (mounted) {
        setState(() {
          _post = post;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push(
      MaterialPageRoute<Post>(
        builder: (_) => EditorScreen(api: widget.api, post: _post),
      ),
    );
    // The editor pops the saved post (the slug follows the title); backing out re-fetches.
    if (saved == null) {
      _load();
    } else if (mounted) {
      setState(() => _post = saved);
    }
  }

  Future<void> _delete() async {
    final post = _post;
    if (post == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.deletePost(post.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final post = _post;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (widget.api.authed && post != null) ...[
            IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: _error != null
          ? Center(
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            )
          : post == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDate(post.createdAt),
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.title,
                    style: theme.textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  MarkdownBody(source: post.body),
                ],
              ),
            ),
    );
  }
}
