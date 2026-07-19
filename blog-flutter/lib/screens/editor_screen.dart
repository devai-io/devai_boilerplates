import 'package:flutter/material.dart';

import '../api.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.api, this.post});

  final ApiClient api;

  /// When set, the screen edits this post; otherwise it creates a new one.
  final Post? post;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final _title = TextEditingController(text: widget.post?.title ?? '');
  late final _body = TextEditingController(text: widget.post?.body ?? '');
  late bool _published = widget.post?.published ?? false;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final existing = widget.post;
      if (existing != null) {
        await widget.api.updatePost(existing.id, {
          'title': _title.text,
          'body': _body.text,
          'published': _published,
        });
      } else {
        final created = await widget.api.createPost(_title.text, _body.text);
        // Posts are created unpublished; flip the flag in a follow-up update.
        if (_published) {
          await widget.api.updatePost(created.id, {'published': true});
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.post == null ? 'New post' : 'Edit post'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _body,
              maxLines: 16,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Body (markdown)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Published'),
              contentPadding: EdgeInsets.zero,
              value: _published,
              onChanged: (value) => setState(() => _published = value),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}
