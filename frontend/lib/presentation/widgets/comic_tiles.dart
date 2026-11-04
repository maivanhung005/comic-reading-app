import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/comic_entity.dart';
import 'secure_media_headers.dart';

class ComicTile extends StatelessWidget {
  final ComicEntity comic;
  final VoidCallback onTap;

  const ComicTile({super.key, required this.comic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = comic.coverUrl.isEmpty
        ? const ColoredBox(color: Colors.black12, child: Icon(Icons.menu_book))
        : CachedNetworkImage(
            imageUrl: comic.coverUrl,
            httpHeaders: secureMediaHeaders(context, comic.coverUrl),
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
          );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 66, height: 88, child: cover),
        ),
        title: Text(
          comic.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${comic.author}\n${comic.tags.join(' · ')}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class RecommendationCard extends StatelessWidget {
  final ComicEntity comic;
  final VoidCallback onTap;

  const RecommendationCard({super.key, required this.comic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = comic.coverUrl.isEmpty
        ? const ColoredBox(color: Colors.black12, child: Icon(Icons.menu_book))
        : CachedNetworkImage(
            imageUrl: comic.coverUrl,
            httpHeaders: secureMediaHeaders(context, comic.coverUrl),
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
          );
    return SizedBox(
      width: 132,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 132, child: cover),
              ),
            ),
            const SizedBox(height: 6),
            Text(comic.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Độ phù hợp ${(comic.similarityScore * 100).round()}%', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
