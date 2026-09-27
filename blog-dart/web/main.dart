import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart';

// Default /api: same origin, forwarded to the API by nginx.
const apiUrl = String.fromEnvironment('API_URL', defaultValue: '/api');
const _tokenKey = 'blog_token';

// The token lives in memory; localStorage only rehydrates it across reloads.
String? _token = window.localStorage.getItem(_tokenKey);

bool get authed => _token != null;

void _setToken(String? value) {
  _token = value;
  if (value == null) {
    window.localStorage.removeItem(_tokenKey);
  } else {
    window.localStorage.setItem(_tokenKey, value);
  }
}

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

Future<dynamic> _request(String method, String path, {Map<String, Object?>? body}) async {
  final headers = Headers();
  if (body != null) headers.append('Content-Type', 'application/json');
  if (_token != null) headers.append('Authorization', 'Bearer $_token');

  final res = await window
      .fetch(
        '$apiUrl$path'.toJS,
        RequestInit(
          method: method,
          headers: headers,
          body: body == null ? null : jsonEncode(body).toJS,
        ),
      )
      .toDart;
  final text = (await res.text().toDart).toDart;

  if (!res.ok) {
    var message = 'HTTP ${res.status}';
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map && decoded['error'] is String) message = decoded['error'] as String;
    } catch (_) {
      // non-JSON error body; keep the status message
    }
    throw ApiException(res.status, message);
  }
  return text.isEmpty ? null : jsonDecode(text);
}

Map<String, dynamic> _asMap(dynamic value) => (value as Map).cast<String, dynamic>();

class PostSummary {
  PostSummary.fromJson(Map<String, dynamic> j)
    : id = '${j['id']}',
      title = j['title'] as String,
      slug = j['slug'] as String,
      excerpt = j['excerpt'] as String,
      publishedAt = j['published_at'] as String;
  final String id, title, slug, excerpt, publishedAt;
}

class Post {
  Post.fromJson(Map<String, dynamic> j)
    : id = '${j['id']}',
      title = j['title'] as String,
      slug = j['slug'] as String,
      body = j['body'] as String,
      published = j['published'] as bool,
      createdAt = j['created_at'] as String;
  final String id, title, slug, body, createdAt;
  final bool published;
}

Future<void> login(String email, String password) async {
  final data = _asMap(
    await _request('POST', '/auth/login', body: {'email': email, 'password': password}),
  );
  _setToken(data['token'] as String);
}

Future<List<PostSummary>> listPosts() async {
  final data = await _request('GET', '/posts') as List<dynamic>;
  return [for (final item in data) PostSummary.fromJson(_asMap(item))];
}

Future<Post> getPost(String slug) async =>
    Post.fromJson(_asMap(await _request('GET', '/posts/${Uri.encodeComponent(slug)}')));

Future<Post> createPost(String title, String body) async =>
    Post.fromJson(_asMap(await _request('POST', '/posts', body: {'title': title, 'body': body})));

Future<Post> updatePost(String id, Map<String, Object?> fields) async =>
    Post.fromJson(_asMap(await _request('PUT', '/posts/${Uri.encodeComponent(id)}', body: fields)));

Future<void> deletePost(String id) async =>
    await _request('DELETE', '/posts/${Uri.encodeComponent(id)}');

HTMLElement el(String tag, {String? cls, String? text}) {
  final node = document.createElement(tag) as HTMLElement;
  if (cls != null) node.className = cls;
  if (text != null) node.textContent = text;
  return node;
}

HTMLAnchorElement link(String href, String text, {String? cls}) =>
    (el('a', cls: cls, text: text) as HTMLAnchorElement)..href = href;

void clear(Element node) {
  while (node.firstChild != null) {
    node.removeChild(node.firstChild!);
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String fmtDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

// Markdown → DOM nodes via textContent (never parsed as HTML); only web/mail links become <a>.
final _safeHref = RegExp(r'^(https?:|mailto:|/|#)', caseSensitive: false);
final _inlineRe = RegExp(r'(`[^`]+`)|(\*\*[^*]+\*\*)|(\*[^*]+\*)|(\[([^\]]+)\]\(([^)\s]+)\))');
final _blockStart = RegExp(r'^(#|```|[-*]\s|> )');
final _heading = RegExp(r'^(#{1,4})\s+(.*)$');
final _bullet = RegExp(r'^[-*]\s+');

List<Node> _inline(String text) {
  final out = <Node>[];
  var last = 0;
  for (final m in _inlineRe.allMatches(text)) {
    if (m.start > last) out.add(Text(text.substring(last, m.start)));
    final whole = m.group(0)!;
    if (m.group(1) != null) {
      out.add(el('code', text: whole.substring(1, whole.length - 1)));
    } else if (m.group(2) != null) {
      out.add(el('strong', text: whole.substring(2, whole.length - 2)));
    } else if (m.group(3) != null) {
      out.add(el('em', text: whole.substring(1, whole.length - 1)));
    } else if (_safeHref.hasMatch(m.group(6)!)) {
      out.add(
        link(m.group(6)!, m.group(5)!)
          ..target = '_blank'
          ..rel = 'noreferrer',
      );
    } else {
      out.add(Text(m.group(5)!));
    }
    last = m.end;
  }
  if (last < text.length) out.add(Text(text.substring(last)));
  return out;
}

HTMLElement _withInline(HTMLElement node, String text) {
  for (final child in _inline(text)) {
    node.appendChild(child);
  }
  return node;
}

HTMLElement renderMarkdown(String source) {
  final root = el('div', cls: 'prose');
  final lines = source.split('\n');
  var i = 0;

  while (i < lines.length) {
    final line = lines[i];

    if (line.trim().isEmpty) {
      i++;
    } else if (line.startsWith('```')) {
      final code = <String>[];
      i++;
      while (i < lines.length && !lines[i].startsWith('```')) {
        code.add(lines[i++]);
      }
      i++; // closing fence
      root.appendChild(el('pre')..appendChild(el('code', text: code.join('\n'))));
    } else if (_heading.hasMatch(line)) {
      final h = _heading.firstMatch(line)!;
      root.appendChild(_withInline(el('h${h.group(1)!.length}'), h.group(2)!));
      i++;
    } else if (_bullet.hasMatch(line)) {
      final ul = el('ul');
      while (i < lines.length && _bullet.hasMatch(lines[i])) {
        ul.appendChild(_withInline(el('li'), lines[i++].replaceFirst(_bullet, '')));
      }
      root.appendChild(ul);
    } else if (line.startsWith('> ')) {
      final quote = <String>[];
      while (i < lines.length && lines[i].startsWith('> ')) {
        quote.add(lines[i++].substring(2));
      }
      root.appendChild(_withInline(el('blockquote'), quote.join(' ')));
    } else {
      final para = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty && !_blockStart.hasMatch(lines[i])) {
        para.add(lines[i++]);
      }
      root.appendChild(_withInline(el('p'), para.join(' ')));
    }
  }
  return root;
}

final _app = document.getElementById('app') as HTMLElement;

void _navigate(String route) {
  if (window.location.hash == '#$route') {
    render(); // hash unchanged → no hashchange event, re-render explicitly
  } else {
    window.location.hash = route;
  }
}

HTMLElement _header() {
  final bar = el('div', cls: 'bar')..appendChild(link('#/', 'blog', cls: 'brand'));
  final nav = el('nav');
  if (authed) {
    nav.appendChild(link('#/write', 'Write'));
    final out = el('button', text: 'Log out');
    out.onclick = ((Event _) {
      _setToken(null);
      _navigate('/');
    }).toJS;
    nav.appendChild(out);
  } else {
    nav.appendChild(link('#/login', 'Log in'));
  }
  bar.appendChild(nav);
  return el('header')..appendChild(bar);
}

HTMLElement _message(String text, {bool isError = false}) =>
    el('p', cls: isError ? 'error' : 'muted', text: text);

Future<void> _postList(HTMLElement main) async {
  main.appendChild(_message('Loading…'));
  try {
    final posts = await listPosts();
    clear(main);
    if (posts.isEmpty) {
      main.appendChild(_message('No posts yet.'));
      return;
    }
    final list = el('ul', cls: 'posts');
    for (final post in posts) {
      list.appendChild(
        el('li')
          ..appendChild(el('time', text: fmtDate(post.publishedAt)))
          ..appendChild(el('h2')..appendChild(link('#/posts/${post.slug}', post.title)))
          ..appendChild(el('p', text: post.excerpt)),
      );
    }
    main.appendChild(list);
  } catch (e) {
    clear(main);
    main.appendChild(_message('$e', isError: true));
  }
}

Future<void> _postDetail(HTMLElement main, String slug) async {
  main.appendChild(_message('Loading…'));
  try {
    final post = await getPost(slug);
    clear(main);
    final article = el('article')
      ..appendChild(el('time', text: fmtDate(post.createdAt)))
      ..appendChild(el('h1', text: post.title));

    if (authed) {
      final del = el('button', text: 'Delete');
      del.onclick = ((Event _) {
        if (!window.confirm('Delete this post?')) return;
        deletePost(post.id).then((_) => _navigate('/')).catchError((Object e) {
          article.appendChild(_message('$e', isError: true));
        });
      }).toJS;
      article.appendChild(
        el('div', cls: 'actions')
          ..appendChild(link('#/edit/${post.slug}', 'Edit'))
          ..appendChild(del),
      );
    }

    article.appendChild(renderMarkdown(post.body));
    main.appendChild(article);
  } catch (e) {
    clear(main);
    main.appendChild(_message('$e', isError: true));
  }
}

void _loginView(HTMLElement main) {
  final email = (el('input') as HTMLInputElement)
    ..type = 'email'
    ..required = true
    ..placeholder = 'Email'
    ..autocomplete = 'email';
  final password = (el('input') as HTMLInputElement)
    ..type = 'password'
    ..required = true
    ..placeholder = 'Password'
    ..autocomplete = 'current-password';
  final error = el('p', cls: 'error');
  final submit = (el('button', cls: 'primary', text: 'Sign in') as HTMLButtonElement)
    ..type = 'submit';

  final form = el('form') as HTMLFormElement;
  form.onsubmit = ((Event e) {
    e.preventDefault();
    submit.disabled = true;
    error.textContent = '';
    login(email.value, password.value).then((_) => _navigate('/')).catchError((Object err) {
      error.textContent = '$err';
      submit.disabled = false;
    });
  }).toJS;

  form
    ..appendChild(email)
    ..appendChild(password)
    ..appendChild(error)
    ..appendChild(submit);
  main.appendChild(
    el('div', cls: 'narrow')
      ..appendChild(el('h1', text: 'Log in'))
      ..appendChild(form),
  );
}

Future<void> _editorView(HTMLElement main, String? slug) async {
  Post? existing;
  if (slug != null) {
    main.appendChild(_message('Loading…'));
    try {
      existing = await getPost(slug);
    } catch (e) {
      clear(main);
      main.appendChild(_message('$e', isError: true));
      return;
    }
    clear(main);
  }

  var id = existing?.id;
  final heading = el('h1', text: id == null ? 'New post' : 'Edit post');
  final title = (el('input') as HTMLInputElement)
    ..type = 'text'
    ..required = true
    ..placeholder = 'Title'
    ..value = existing?.title ?? '';
  final body = (el('textarea') as HTMLTextAreaElement)
    ..required = true
    ..placeholder = 'Write in markdown…'
    ..rows = 16
    ..value = existing?.body ?? '';
  final published = (el('input') as HTMLInputElement)
    ..type = 'checkbox'
    ..checked = existing?.published ?? false;
  final submit = (el('button', cls: 'primary', text: 'Save') as HTMLButtonElement)..type = 'submit';
  final notice = el('p', cls: 'muted');
  final error = el('p', cls: 'error');

  Future<Post> save() async {
    final current = id;
    if (current != null) {
      return updatePost(current, {
        'title': title.value,
        'body': body.value,
        'published': published.checked,
      });
    }
    final post = await createPost(title.value, body.value);
    // Posts are created unpublished; flip the flag in a follow-up update.
    return published.checked ? updatePost(post.id, {'published': true}) : post;
  }

  final form = el('form') as HTMLFormElement;
  form.onsubmit = ((Event e) {
    e.preventDefault();
    submit.disabled = true;
    notice.textContent = '';
    error.textContent = '';
    save()
        .then((post) {
          if (post.published) {
            _navigate('/posts/${post.slug}');
            return;
          }
          // The API never serves drafts back, so keep editing this one right here.
          id = post.id;
          heading.textContent = 'Edit post';
          notice.textContent = 'Draft saved. Tick Published and save again to make it public.';
          submit.disabled = false;
        })
        .catchError((Object err) {
          error.textContent = '$err';
          submit.disabled = false;
        });
  }).toJS;

  final toggle = el('label', cls: 'toggle')
    ..appendChild(published)
    ..appendChild(Text('Published'));
  form
    ..appendChild(title)
    ..appendChild(body)
    ..appendChild(
      el('div', cls: 'row')
        ..appendChild(toggle)
        ..appendChild(submit),
    )
    ..appendChild(notice)
    ..appendChild(error);
  main
    ..appendChild(heading)
    ..appendChild(form);
}

// Hash routes (#/, #/posts/<slug>, #/login, #/write, #/edit/<slug>) need no server config.
void render() {
  clear(_app);
  final main = el('main');
  _app
    ..appendChild(_header())
    ..appendChild(main);

  final hash = window.location.hash;
  final route = hash.length <= 1 ? '/' : Uri.decodeComponent(hash.substring(1));

  if (route == '/login') {
    _loginView(main);
  } else if (route == '/write') {
    _editorView(main, null);
  } else if (route.startsWith('/edit/')) {
    _editorView(main, route.substring('/edit/'.length));
  } else if (route.startsWith('/posts/')) {
    _postDetail(main, route.substring('/posts/'.length));
  } else {
    _postList(main);
  }
}

void main() {
  window.addEventListener('hashchange', ((Event _) => render()).toJS);
  render();
}
