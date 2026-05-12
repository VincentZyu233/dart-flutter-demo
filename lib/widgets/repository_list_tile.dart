import 'package:flutter/material.dart';

import '../models/page3_enums.dart';
import '../services/github_repository_service.dart';
import 'tag.dart';

class RepositoryListTile extends StatefulWidget {
  final GitHubRepositoryItem repository;
  final DensityMode density;
  final int delayMs;
  final VoidCallback onOpen;

  const RepositoryListTile({
    super.key,
    required this.repository,
    required this.density,
    required this.delayMs,
    required this.onOpen,
  });

  @override
  State<RepositoryListTile> createState() => _RepositoryListTileState();
}

class _RepositoryListTileState extends State<RepositoryListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = widget.repository;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + widget.delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hovered
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            onTap: widget.onOpen,
            leading: CircleAvatar(
              backgroundImage: NetworkImage(repo.ownerAvatarUrl),
            ),
            title: Text(
              repo.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              repo.description?.isNotEmpty == true
                  ? repo.description!
                  : 'No description provided.',
              maxLines:
                  widget.density == DensityMode.one || widget.density == DensityMode.two
                      ? 3
                      : 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Wrap(
              spacing: 6,
              children: [
                Tag(text: '★ ${repo.stars}'),
                Tag(text: repo.language ?? 'n/a'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
