import 'dart:convert';
import 'dart:io';

class GitHubRepositorySource {
  final String rawUrl;
  final GitHubRepositorySourceKind kind;
  final String handle;

  const GitHubRepositorySource({
    required this.rawUrl,
    required this.kind,
    required this.handle,
  });

  String get label => switch (kind) {
        GitHubRepositorySourceKind.user => '@$handle',
        GitHubRepositorySourceKind.organization => '$handle org',
      };
}

enum GitHubRepositorySourceKind {
  user,
  organization,
}

class GitHubRepositoryItem {
  final String id;
  final String name;
  final String fullName;
  final String htmlUrl;
  final String owner;
  final String ownerAvatarUrl;
  final String? description;
  final String? language;
  final int stars;
  final int forks;
  final bool archived;
  final bool isPrivate;
  final DateTime? updatedAt;
  final GitHubRepositorySource source;

  const GitHubRepositoryItem({
    required this.id,
    required this.name,
    required this.fullName,
    required this.htmlUrl,
    required this.owner,
    required this.ownerAvatarUrl,
    required this.description,
    required this.language,
    required this.stars,
    required this.forks,
    required this.archived,
    required this.isPrivate,
    required this.updatedAt,
    required this.source,
  });

  factory GitHubRepositoryItem.fromJson(
    Map<String, dynamic> json,
    GitHubRepositorySource source,
  ) {
    final owner = json['owner'] as Map<String, dynamic>? ?? const {};
    return GitHubRepositoryItem(
      id: (json['id'] ?? json['full_name'] ?? json['html_url']).toString(),
      name: (json['name'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      htmlUrl: (json['html_url'] ?? '').toString(),
      owner: (owner['login'] ?? '').toString(),
      ownerAvatarUrl: (owner['avatar_url'] ?? '').toString(),
      description: (json['description'] as String?)?.trim(),
      language: (json['language'] as String?)?.trim(),
      stars: (json['stargazers_count'] as num?)?.toInt() ?? 0,
      forks: (json['forks_count'] as num?)?.toInt() ?? 0,
      archived: json['archived'] == true,
      isPrivate: json['private'] == true,
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
      source: source,
    );
  }
}

class GitHubRepositoryFetchResult {
  final List<GitHubRepositoryItem> repositories;
  final List<String> logs;

  const GitHubRepositoryFetchResult({
    required this.repositories,
    required this.logs,
  });
}

class GitHubRepositorySourceParseException implements Exception {
  final String message;

  const GitHubRepositorySourceParseException(this.message);

  @override
  String toString() => message;
}

class GitHubRepositoryService {
  static final RegExp _userPathPattern =
      RegExp(r'^/([A-Za-z0-9](?:[A-Za-z0-9-]{0,38}))/?$');
  static final RegExp _orgPathPattern =
      RegExp(r'^/orgs/([A-Za-z0-9](?:[A-Za-z0-9-]{0,38}))/repositories/?$');

  GitHubRepositorySource parseSource(String rawUrl) {
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.toLowerCase() != 'github.com') {
      throw const GitHubRepositorySourceParseException(
        'Only GitHub repository pages are allowed.',
      );
    }

    final orgMatch = _orgPathPattern.firstMatch(uri.path);
    if (orgMatch != null) {
      return GitHubRepositorySource(
        rawUrl: trimmed,
        kind: GitHubRepositorySourceKind.organization,
        handle: orgMatch.group(1)!,
      );
    }

    final userMatch = _userPathPattern.firstMatch(uri.path);
    final tab = uri.queryParameters['tab'];
    if (userMatch != null && (tab == null || tab == 'repositories')) {
      return GitHubRepositorySource(
        rawUrl: trimmed,
        kind: GitHubRepositorySourceKind.user,
        handle: userMatch.group(1)!,
      );
    }

    throw const GitHubRepositorySourceParseException(
      'Use a personal repositories page or an organization repositories page.',
    );
  }

  Future<GitHubRepositoryFetchResult> fetchRepositories({
    required List<String> sourceUrls,
    required bool useProxy,
    required String proxyUrl,
  }) async {
    final logs = <String>[];
    final parsedSources = <GitHubRepositorySource>[];

    for (final sourceUrl in sourceUrls) {
      parsedSources.add(parseSource(sourceUrl));
    }

    final client = HttpClient();
    if (useProxy) {
      final proxy = Uri.tryParse(proxyUrl.trim());
      if (proxy == null || proxy.host.isEmpty || proxy.port <= 0) {
        throw const GitHubRepositorySourceParseException(
          'Proxy URL is invalid.',
        );
      }
      client.findProxy = (_) => 'PROXY ${proxy.host}:${proxy.port}';
      logs.add('Proxy enabled: ${proxy.scheme}://${proxy.host}:${proxy.port}');
    } else {
      logs.add('Proxy disabled.');
    }

    try {
      final allRepositories = <GitHubRepositoryItem>[];
      for (final source in parsedSources) {
        logs.add('Fetching ${source.rawUrl}');
        final repositories = await _fetchSource(client, source);
        logs.add('Loaded ${repositories.length} repositories from ${source.label}');
        allRepositories.addAll(repositories);
      }

      final deduped = <String, GitHubRepositoryItem>{};
      for (final repository in allRepositories) {
        deduped[repository.id] = repository;
      }

      return GitHubRepositoryFetchResult(
        repositories: deduped.values.toList(),
        logs: logs,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<List<GitHubRepositoryItem>> _fetchSource(
    HttpClient client,
    GitHubRepositorySource source,
  ) async {
    final repositories = <GitHubRepositoryItem>[];
    for (var page = 1; page <= 5; page++) {
      final uri = switch (source.kind) {
        GitHubRepositorySourceKind.user => Uri.https(
            'api.github.com',
            '/users/${source.handle}/repos',
            <String, String>{
              'type': 'owner',
              'sort': 'updated',
              'per_page': '100',
              'page': '$page',
            },
          ),
        GitHubRepositorySourceKind.organization => Uri.https(
            'api.github.com',
            '/orgs/${source.handle}/repos',
            <String, String>{
              'type': 'public',
              'sort': 'updated',
              'per_page': '100',
              'page': '$page',
            },
          ),
      };

      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'dart_flutter_demo/0.2');
      request.headers.set('X-GitHub-Api-Version', '2022-11-28');

      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'GitHub API request failed (${response.statusCode}) for ${source.handle}: $body',
          uri: uri,
        );
      }

      final json = jsonDecode(body);
      if (json is! List) {
        throw HttpException('GitHub API returned an unexpected payload.', uri: uri);
      }

      final pageItems = json
          .whereType<Map>()
          .map((item) => GitHubRepositoryItem.fromJson(
                Map<String, dynamic>.from(item),
                source,
              ))
          .toList();

      repositories.addAll(pageItems);
      if (pageItems.length < 100) {
        break;
      }
    }
    return repositories;
  }
}
