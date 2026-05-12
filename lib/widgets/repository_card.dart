import 'package:flutter/material.dart';

import '../models/page3_enums.dart';
import '../services/github_repository_service.dart';
import 'tag.dart';

class RepositoryCard extends StatefulWidget {
  final GitHubRepositoryItem repository;
  final DensityMode density;
  final EdgeInsets padding;
  final double radius;
  final int delayMs;
  final VoidCallback onOpen;

  const RepositoryCard({
    super.key,
    required this.repository,
    required this.density,
    required this.padding,
    required this.radius,
    required this.delayMs,
    required this.onOpen,
  });

  @override
  State<RepositoryCard> createState() => _RepositoryCardState();
}

class _RepositoryCardState extends State<RepositoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = widget.repository;
    final scale = _hovered ? 1.02 : 1.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + widget.delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(widget.radius),
            elevation: _hovered ? 4 : 1,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.radius),
              onTap: widget.onOpen,
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.radius),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(repo.ownerAvatarUrl),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                repo.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                repo.source.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      repo.description?.isNotEmpty == true
                          ? repo.description!
                          : 'No description provided.',
                      maxLines: widget.density == DensityMode.one ? 4 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Tag(text: repo.fullName),
                        if (repo.language != null && repo.language!.isNotEmpty)
                          Tag(text: repo.language!),
                        Tag(text: '★ ${repo.stars}'),
                        Tag(text: '⑂ ${repo.forks}'),
                        if (repo.archived) const Tag(text: 'Archived'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
