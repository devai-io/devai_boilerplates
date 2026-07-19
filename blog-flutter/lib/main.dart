import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/posts_screen.dart';

void main() {
  runApp(BlogApp(api: ApiClient()));
}

class BlogApp extends StatelessWidget {
  const BlogApp({super.key, required this.api});

  final ApiClient api;

  ThemeData _theme(Brightness brightness) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: brightness),
        appBarTheme: const AppBarTheme(centerTitle: false),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blog',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      // Dark-first: follow the system but default builds showcase dark.
      themeMode: ThemeMode.dark,
      home: PostsScreen(api: api),
    );
  }
}
