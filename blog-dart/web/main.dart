// Minimal hand-rolled SPA over the devai.io blog API.
// Hash routing: #/ (list), #/login, #/write, #/edit/<slug>, #/<slug> (detail).

import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart';

// ---------------------------------------------------------------------------
// Config + auth state
// ---------------------------------------------------------------------------

const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');
const _tokenKey = 'blog_token';

// Token lives in memory; localStorage only rehydrates it across reloads.
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

// ---------------------------------------------------------------------------
// API client
// ---------------------------------------------------------------------------

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
  final data = _asMap(await _request('POST', '/auth/login', body: {'email': email, 'password': password}));
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

// ---------------------------------------------------------------------------
// DOM helpers
// ---------------------------------------------------------------------------

HTMLElement el(String tag, {String? cls, String? text}) {
  final node = document.createElement(tag) as HTMLElement;
  if (cls != null) node.className = cls;
  if (text != null) node.textContent = text;
  return node;
}

HTMLAnchorElement link(String href, String text, String cls) =>
    (el('a', cls: cls, text: text) as HTMLAnchorElement)..href = href;

void clear(Element node) {
  while (node.firstChild != null) {
    node.removeChild(node.firstChild!);
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

// ---------------------------------------------------------------------------
// Markdown → DOM (headings, paragraphs, fences, lists, quotes, inline marks)
// ---------------------------------------------------------------------------

List<Node> _inline(String text) {
  final out = <Node>[];
  final re = RegExp(r'(`[^`]+`)|(\*\*[^*]+\*\*)|(\*[^*]+\*)|(\[([^\]]+)\]\(([^)\s]+)\))');
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) out.add(Text(text.substring(last, m.start)));
    if (m.group(1) != null) {
      final code = m.group(1)!;
      out.add(el('code',
          cls: 'bg-zinc-100 dark:bg-zinc-900 px-1.5 py-0.5 rounded font-mono text-sm',
          text: code.substring(1, code.length - 1)));
    } else if (m.group(2) != null) {
      final bold = m.group(2)!;
      out.add(el('strong', text: bold.substring(2, bold.length - 2)));
    } else if (m.group(3) != null) {
      final italic = m.group(3)!;
      out.add(el('em', text: italic.substring(1, italic.length - 1)));
    } else {
      out.add((el('a',
          cls: 'text-violet-600 dark:text-violet-400 underline underline-offset-2',
          text: m.group(5)!) as HTMLAnchorElement)
        ..href = m.group(6)!);
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
  final root = el('div', cls: 'text-zinc-700 dark:text-zinc-300 leading-relaxed');
  final lines = source.split('\n');
  final headingCls = 'font-semibold text-zinc-900 dark:text-zinc-100 mt-8 mb-3';
  final block = RegExp(r'^(#|```|[-*]\s|> )');
  var i = 0;

  while (i < lines.length) {
    final line = lines[i];

    if (line.trim().isEmpty) {
      i++;
      continue;
    }

    if (line.startsWith('```')) {
      final code = <String>[];
      i++;
      while (i < lines.length && !lines[i].startsWith('```')) {
        code.add(lines[i++]);
      }
      i++; // closing fence
      final pre = el('pre',
          cls: 'bg-zinc-100 dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 '
              'rounded-lg p-4 my-4 overflow-x-auto text-sm');
      pre.appendChild(el('code', cls: 'font-mono', text: code.join('\n')));
      root.appendChild(pre);
      continue;
    }

    final h = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(line);
    if (h != null) {
      final level = h.group(1)!.length;
      final size = ['text-2xl', 'text-xl', 'text-lg', 'text-base'][level - 1];
      root.appendChild(_withInline(el('h$level', cls: '$headingCls $size'), h.group(2)!));
      i++;
      continue;
    }

    if (RegExp(r'^[-*]\s+').hasMatch(line)) {
      final ul = el('ul', cls: 'list-disc pl-6 my-4 space-y-1');
      while (i < lines.length && RegExp(r'^[-*]\s+').hasMatch(lines[i])) {
        ul.appendChild(_withInline(el('li'), lines[i++].replaceFirst(RegExp(r'^[-*]\s+'), '')));
      }
      root.appendChild(ul);
      continue;
    }

    if (line.startsWith('> ')) {
      final quote = <String>[];
      while (i < lines.length && lines[i].startsWith('> ')) {
        quote.add(lines[i++].substring(2));
      }
      root.appendChild(_withInline(
          el('blockquote',
              cls: 'border-l-2 border-violet-500 pl-4 my-4 italic text-zinc-500 dark:text-zinc-400'),
          quote.join(' ')));
      continue;
    }

    final para = <String>[];
    while (i < lines.length && lines[i].trim().isNotEmpty && !block.hasMatch(lines[i])) {
      para.add(lines[i++]);
    }
    root.appendChild(_withInline(el('p', cls: 'my-4'), para.join(' ')));
  }

  return root;
}

// ---------------------------------------------------------------------------
// Views
// ---------------------------------------------------------------------------

final _app = document.getElementById('app') as HTMLElement;
const _navLink = 'hover:text-zinc-900 dark:hover:text-zinc-100';
const _fieldCls = 'w-full rounded-lg border border-zinc-300 dark:border-zinc-700 bg-transparent '
    'px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent';
const _buttonCls = 'rounded-lg bg-violet-600 hover:bg-violet-500 disabled:opacity-50 px-4 py-2 '
    'text-sm font-medium text-white transition-colors';

void _navigate(String route) {
  if (window.location.hash == '#$route') {
    render(); // hash unchanged → no hashchange event, re-render explicitly
  } else {
    window.location.hash = route;
  }
}

HTMLElement _header() {
  final header = el('header', cls: 'border-b border-zinc-200 dark:border-zinc-800');
  final bar = el('div', cls: 'mx-auto max-w-2xl px-6 py-5 flex items-center justify-between');
  bar.appendChild(link('#/', 'blog', 'font-semibold tracking-tight'));

  final nav = el('nav', cls: 'flex items-center gap-4 text-sm text-zinc-500 dark:text-zinc-400');
  if (authed) {
    nav.appendChild(link('#/write', 'Write', _navLink));
    final out = el('button', cls: _navLink, text: 'Log out');
    out.onclick = ((Event _) {
      _setToken(null);
      _navigate('/');
    }).toJS;
    nav.appendChild(out);
  } else {
    nav.appendChild(link('#/login', 'Log in', _navLink));
  }
  bar.appendChild(nav);
  header.appendChild(bar);
  return header;
}

HTMLElement _message(String text, {bool isError = false}) =>
    el('p', cls: isError ? 'text-red-500 text-sm' : 'text-zinc-500 text-sm', text: text);

Future<void> _postList(HTMLElement main) async {
  main.appendChild(_message('Loading…'));
  try {
    final posts = await listPosts();
    clear(main);
    if (posts.isEmpty) {
      main.appendChild(_message('No posts yet.'));
      return;
    }
    final list = el('ul', cls: 'space-y-10');
    for (final post in posts) {
      final item = el('li');
      item.appendChild(
          el('time', cls: 'text-xs uppercase tracking-wide text-zinc-500', text: fmtDate(post.publishedAt)));
      final title = el('h2', cls: 'mt-1 text-xl font-semibold tracking-tight');
      title.appendChild(
          link('#/${post.slug}', post.title, 'hover:text-violet-600 dark:hover:text-violet-400'));
      item.appendChild(title);
      item.appendChild(el('p',
          cls: 'mt-2 text-sm text-zinc-600 dark:text-zinc-400 leading-relaxed', text: post.excerpt));
      list.appendChild(item);
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
    final article = el('article');
    article.appendChild(
        el('time', cls: 'text-xs uppercase tracking-wide text-zinc-500', text: fmtDate(post.createdAt)));
    article.appendChild(el('h1', cls: 'mt-1 text-3xl font-semibold tracking-tight', text: post.title));

    if (authed) {
      final actions = el('div', cls: 'mt-3 flex gap-3 text-sm');
      actions.appendChild(
          link('#/edit/${post.slug}', 'Edit', 'text-violet-600 dark:text-violet-400 hover:underline'));
      final del = el('button', cls: 'text-red-500 hover:underline', text: 'Delete');
      del.onclick = ((Event _) {
        if (!window.confirm('Delete this post?')) return;
        deletePost(post.id).then((_) => _navigate('/')).catchError((Object e) {
          article.appendChild(_message('$e', isError: true));
        });
      }).toJS;
      actions.appendChild(del);
      article.appendChild(actions);
    }

    final body = el('div', cls: 'mt-6');
    body.appendChild(renderMarkdown(post.body));
    article.appendChild(body);
    main.appendChild(article);
  } catch (e) {
    clear(main);
    main.appendChild(_message('$e', isError: true));
  }
}

void _loginView(HTMLElement main) {
  final wrap = el('div', cls: 'mx-auto max-w-sm');
  wrap.appendChild(el('h1', cls: 'text-2xl font-semibold tracking-tight', text: 'Log in'));

  final form = el('form', cls: 'mt-6 space-y-4') as HTMLFormElement;
  final email = el('input', cls: _fieldCls) as HTMLInputElement
    ..type = 'email'
    ..required = true
    ..placeholder = 'Email'
    ..autocomplete = 'email';
  final password = el('input', cls: _fieldCls) as HTMLInputElement
    ..type = 'password'
    ..required = true
    ..placeholder = 'Password'
    ..autocomplete = 'current-password';
  final error = el('p', cls: 'text-sm text-red-500 hidden');
  final submit = el('button', cls: '$_buttonCls w-full', text: 'Sign in') as HTMLButtonElement
    ..type = 'submit';

  form.onsubmit = ((Event e) {
    e.preventDefault();
    submit.disabled = true;
    error.className = 'text-sm text-red-500 hidden';
    login(email.value, password.value).then((_) => _navigate('/')).catchError((Object err) {
      error.textContent = '$err';
      error.className = 'text-sm text-red-500';
      submit.disabled = false;
    });
  }).toJS;

  form.appendChild(email);
  form.appendChild(password);
  form.appendChild(error);
  form.appendChild(submit);
  wrap.appendChild(form);
  main.appendChild(wrap);
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

  main.appendChild(el('h1',
      cls: 'text-2xl font-semibold tracking-tight', text: existing == null ? 'New post' : 'Edit post'));

  final form = el('form', cls: 'mt-6 space-y-4') as HTMLFormElement;
  final title = el('input', cls: _fieldCls) as HTMLInputElement
    ..type = 'text'
    ..required = true
    ..placeholder = 'Title'
    ..value = existing?.title ?? '';
  final body = el('textarea', cls: '$_fieldCls font-mono resize-y') as HTMLTextAreaElement
    ..required = true
    ..placeholder = 'Write in markdown…'
    ..rows = 16
    ..value = existing?.body ?? '';
  final published = el('input', cls: 'h-4 w-4 rounded accent-violet-600') as HTMLInputElement
    ..type = 'checkbox'
    ..checked = existing?.published ?? false;
  final error = el('p', cls: 'text-sm text-red-500 hidden');
  final submit = el('button', cls: _buttonCls, text: 'Save') as HTMLButtonElement..type = 'submit';

  final toggle = el('label',
      cls: 'flex items-center gap-2 text-sm text-zinc-600 dark:text-zinc-400 cursor-pointer');
  toggle.appendChild(published);
  toggle.appendChild(Text('Published'));

  final row = el('div', cls: 'flex items-center justify-between');
  row.appendChild(toggle);
  row.appendChild(submit);

  final id = existing?.id;
  form.onsubmit = ((Event e) {
    e.preventDefault();
    submit.disabled = true;
    error.className = 'text-sm text-red-500 hidden';

    Future<Post> save() async {
      if (id != null) {
        return updatePost(id, {
          'title': title.value,
          'body': body.value,
          'published': published.checked,
        });
      }
      var post = await createPost(title.value, body.value);
      // Posts are created unpublished; flip the flag in a follow-up update.
      if (published.checked) post = await updatePost(post.id, {'published': true});
      return post;
    }

    save().then((post) => _navigate(post.published ? '/${post.slug}' : '/')).catchError((Object err) {
      error.textContent = '$err';
      error.className = 'text-sm text-red-500';
      submit.disabled = false;
    });
  }).toJS;

  form.appendChild(title);
  form.appendChild(body);
  form.appendChild(row);
  form.appendChild(error);
  main.appendChild(form);
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

void render() {
  clear(_app);
  _app.appendChild(_header());
  final main = el('main', cls: 'mx-auto max-w-2xl px-6 py-10');
  _app.appendChild(main);

  final hash = window.location.hash;
  final route = hash.length <= 1 ? '/' : Uri.decodeComponent(hash.substring(1));

  if (route == '/') {
    _postList(main);
  } else if (route == '/login') {
    _loginView(main);
  } else if (route == '/write') {
    _editorView(main, null);
  } else if (route.startsWith('/edit/')) {
    _editorView(main, route.substring('/edit/'.length));
  } else {
    _postDetail(main, route.substring(1));
  }
}

void main() {
  window.addEventListener('hashchange', ((Event _) => render()).toJS);
  render();
}
