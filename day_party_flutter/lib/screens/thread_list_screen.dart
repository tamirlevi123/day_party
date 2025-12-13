import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/thread_provider.dart';
import '../providers/memes_provider.dart';
import '../widgets/user_profile_action.dart';
import '../widgets/html_content_widget.dart';
import '../widgets/meme_card.dart';

class ThreadListScreen extends StatelessWidget {
  final String topicId;

  const ThreadListScreen({super.key, required this.topicId});

  /// Extract plain text preview from Delta JSON or HTML
  Widget _buildDescriptionPreview(String description) {
    // Try to parse as Delta JSON
    try {
      final decoded = jsonDecode(description);
      if (decoded is Map && decoded.containsKey('ops')) {
        // It's Delta JSON - extract plain text
        final ops = decoded['ops'] as List;
        final buffer = StringBuffer();
        for (final op in ops) {
          if (op is Map && op.containsKey('insert')) {
            final insert = op['insert'];
            if (insert is String) {
              buffer.write(insert);
            }
          }
        }
        final plainText = buffer.toString().trim();
        return Text(
          plainText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      }
    } catch (e) {
      // Not JSON, treat as plain text or HTML
    }
    
    // Check if it's HTML
    if (description.trim().startsWith('<')) {
      // Use HtmlContentWidget but limit height
      return SizedBox(
        height: 40,
        child: HtmlContentWidget(
          content: description,
          format: TextFormat.html,
        ),
      );
    }
    
    // Plain text
    return Text(
      description,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThreadProvider()..loadThreads(topicId),
        ),
        // Ensure MemesProvider is available and initialized
        ChangeNotifierProxyProvider<ThreadProvider, MemesProvider>(
          create: (_) => MemesProvider(),
          update: (_, __, memesProvider) {
            // Load memes if not already loaded
            if (memesProvider?.memesTopicId == null && !memesProvider!.isLoading) {
              memesProvider.loadMemes();
            }
            return memesProvider ?? MemesProvider();
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Threads'),
          actions: const [
            UserProfileAction(),
          ],
        ),
        body: Consumer<ThreadProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${provider.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.loadThreads(topicId),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (provider.threads.isEmpty) {
              return const Center(
                child: Text('No threads in this topic'),
              );
            }

            return Consumer<MemesProvider>(
              builder: (context, memesProvider, _) {
                // Ensure memes are loaded if not already (needed to detect memes topic)
                if (memesProvider.memesTopicId == null && !memesProvider.isLoading) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    memesProvider.loadMemes();
                  });
                }
                
                // Check if we're viewing the memes topic
                final isMemesTopic = memesProvider.isMemesTopic(topicId);
                
                if (isMemesTopic) {
                  // For memes topic: show ALL threads as meme cards with images
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.threads.length,
                    itemBuilder: (context, index) {
                      final thread = provider.threads[index];
                      return MemeCard(
                        key: ValueKey('meme_${thread.threadId}_$index'),
                        memeThread: thread,
                      );
                    },
                  );
                }
                
                // For other topics: mix memes every 3 threads
                const memeInterval = 3;
                final memeCount = (provider.threads.length / memeInterval).floor();
                final totalItems = provider.threads.length + memeCount;
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: totalItems,
                  itemBuilder: (context, index) {
                    // Determine if this should be a meme or a thread
                    final position = index + 1;
                    final shouldShowMeme = position % (memeInterval + 1) == 0 && 
                                          memesProvider.hasMemes;
                    
                    if (shouldShowMeme) {
                      // Use index to deterministically select a meme for this position
                      // This ensures the same meme is shown at the same position every time
                      final memeIndex = (position ~/ (memeInterval + 1)) - 1;
                      final meme = memesProvider.getMemeByIndex(memeIndex);
                      if (meme != null) {
                        return MemeCard(
                          key: ValueKey('meme_${meme.threadId}_$index'), // Unique key per meme card instance
                          memeThread: meme,
                        );
                      }
                    }
                    
                    // Calculate thread index (accounting for memes shown before)
                    final threadIndex = index - (position ~/ (memeInterval + 1));
                    if (threadIndex >= 0 && threadIndex < provider.threads.length) {
                      final thread = provider.threads[threadIndex];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(
                            thread.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (thread.description != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: _buildDescriptionPreview(thread.description!),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${thread.nodeCount} posts',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/thread-detail',
                              arguments: thread.threadId,
                            );
                          },
                        ),
                      );
                    }
                    
                    return const SizedBox.shrink();
                  },
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.pushNamed(
              context,
              '/create-thread',
              arguments: topicId,
            );
            // Refresh threads if a thread was created
            if (result != null && context.mounted) {
              final provider = Provider.of<ThreadProvider>(context, listen: false);
              await provider.loadThreads(topicId);
            }
          },
          child: const Icon(Icons.add),
          tooltip: 'צור דיון חדש',
        ),
      ),
    );
  }
}

