import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/thread_provider.dart';
import '../providers/memes_provider.dart';
import '../providers/knesset/knesset_database_provider.dart';
import '../widgets/user_profile_action.dart';
import '../widgets/html_content_widget.dart';
import '../widgets/meme_card.dart';

class ThreadListScreen extends StatelessWidget {
  final String topicId;

  const ThreadListScreen({super.key, required this.topicId});

  /// Get unique statuses for Knesset 25 bills, grouped by description
  /// Returns a list where each entry has a description and all StatusIDs with that description
  Future<List<Map<String, dynamic>>> _getKnesset25Statuses(KnessetDatabaseProvider provider) async {
    try {
      // Get all statuses and filter to those that appear in Knesset 25 bills
      final allStatuses = await provider.getAllStatuses();
      final bills = await provider.getBillsByKnesset(knessetNum: 25);
      final statusIDsInKnesset25 = bills.map((b) => b.statusID).toSet();
      
      // Filter statuses to only those that appear in Knesset 25
      final knesset25Statuses = allStatuses
          .where((status) => statusIDsInKnesset25.contains(status['StatusID']))
          .toList();
      
      // Group by description (Desc field) - treat statuses with same name as one
      final Map<String, List<int>> statusesByDesc = {};
      for (final status in knesset25Statuses) {
        final desc = status['Desc'] as String;
        final statusID = status['StatusID'] as int;
        if (!statusesByDesc.containsKey(desc)) {
          statusesByDesc[desc] = [];
        }
        statusesByDesc[desc]!.add(statusID);
      }
      
      // Convert to list format with description and all StatusIDs
      final uniqueStatuses = statusesByDesc.entries.map((entry) {
        final statusIDs = entry.value;
        statusIDs.sort(); // Sort StatusIDs for consistency
        return {
          'Desc': entry.key,
          'StatusIDs': statusIDs, // List of all StatusIDs with this description
          'StatusID': statusIDs.first, // Primary StatusID (first one, for display)
        };
      }).toList();
      
      // Sort by description
      uniqueStatuses.sort((a, b) => (a['Desc'] as String).compareTo(b['Desc'] as String));
      
      return uniqueStatuses;
    } catch (e) {
      return [];
    }
  }


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
          create: (_) => ThreadProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => KnessetDatabaseProvider(),
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
        body: Column(
          children: [
            // Status filter dropdown
            Consumer<KnessetDatabaseProvider>(
              builder: (context, knessetProvider, _) {
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getKnesset25Statuses(knessetProvider),
                  builder: (context, snapshot) {
                    return Consumer<ThreadProvider>(
                      builder: (context, threadProvider, _) {
                        // Always show the dropdown, even if statuses are loading or empty
                        final statuses = snapshot.hasData ? snapshot.data! : [];
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Builder(
                            builder: (context) {
                              // Get current filter value
                              final currentFilter = threadProvider.statusFilter;
                              
                              // Build items list first
                              final items = <DropdownMenuItem<String?>>[
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('הכל'),
                                ),
                              ];
                              
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                items.add(
                                  const DropdownMenuItem<String?>(
                                    value: 'loading',
                                    enabled: false,
                                    child: Text('טוען...'),
                                  ),
                                );
                              }
                              
                              // Add status items
                              for (final status in statuses) {
                                final statusIDs = status['StatusIDs'] as List<int>;
                                final desc = status['Desc'] as String;
                                final statusIDsValue = statusIDs.join(',');
                                final statusIDsDisplay = statusIDs.length > 1 
                                  ? statusIDs.join(', ')
                                  : statusIDs.first.toString();
                                items.add(
                                  DropdownMenuItem<String?>(
                                    value: statusIDsValue,
                                    child: Text('$desc ($statusIDsDisplay)'),
                                  ),
                                );
                              }
                              
                              // Check if current filter value exists in the items
                              final hasCurrentValue = currentFilter == null || 
                                items.any((item) => item.value == currentFilter);
                              
                              // If current value doesn't exist in items, use null to avoid assertion error
                              // But keep the filter active in the provider (it will still filter threads)
                              final displayValue = hasCurrentValue ? currentFilter : null;
                              
                              return DropdownButtonFormField<String?>(
                                value: displayValue,
                                decoration: const InputDecoration(
                                  labelText: 'סטטוס',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: items,
                                onChanged: snapshot.connectionState == ConnectionState.waiting 
                                  ? null 
                                  : (value) {
                                      final memesProvider = Provider.of<MemesProvider>(context, listen: false);
                                      threadProvider.setStatusFilter(
                                        topicId, 
                                        value,
                                        availableMemes: memesProvider.hasMemes ? memesProvider.memes : null,
                                      );
                                    },
                                isExpanded: true,
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            // Thread list
            Expanded(
              child: Consumer<ThreadProvider>(
                builder: (context, provider, child) {
                  return Consumer<MemesProvider>(
                    builder: (context, memesProvider, _) {
                      // Load threads when provider is first created
                      // Ensure default filter '114' is applied on first load
                      if (provider.threads.isEmpty && !provider.isLoading) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          // If statusFilter is null, set it to default '114' before loading
                          if (provider.statusFilter == null) {
                            provider.setStatusFilter(topicId, '114', availableMemes: memesProvider.hasMemes ? memesProvider.memes : null);
                          } else {
                            provider.loadThreads(topicId, availableMemes: memesProvider.hasMemes ? memesProvider.memes : null);
                          }
                        });
                      }
                      
                      // Ensure memes are loaded if not already (needed to detect memes topic)
                      if (memesProvider.memesTopicId == null && !memesProvider.isLoading) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          memesProvider.loadMemes();
                        });
                      }
                      
                      // Reassign memes when they become available after threads are already loaded
                      if (provider.threads.isNotEmpty && 
                          memesProvider.hasMemes && 
                          provider.memeAssignments.isEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          provider.reassignMemes(memesProvider.memes);
                        });
                      }
                      
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
                                onPressed: () => provider.loadThreads(topicId, availableMemes: memesProvider.hasMemes ? memesProvider.memes : null),
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
                      
                      // For other topics: mix memes every 3 threads using pre-assigned memes
                      const memeInterval = 3;
                      final memeCount = (provider.threads.length / memeInterval).floor();
                      final totalItems = provider.threads.length + memeCount;
                      
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: totalItems,
                        itemBuilder: (context, index) {
                          // Check if this position has a pre-assigned meme
                          if (provider.memeAssignments.containsKey(index)) {
                            final meme = provider.memeAssignments[index]!;
                            return MemeCard(
                              key: ValueKey('meme_${meme.threadId}_$index'),
                              memeThread: meme,
                            );
                          }
                          
                          // Calculate thread index (accounting for memes shown before)
                          // Count how many memes appear before this index
                          int memesBefore = 0;
                          for (int i = 0; i < index; i++) {
                            if (provider.memeAssignments.containsKey(i)) {
                              memesBefore++;
                            }
                          }
                          // Thread index is the current index minus memes shown before
                          final threadIndex = index - memesBefore;
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
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          return Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                '${thread.nodeCount} posts',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              if (thread.billId != null)
                                                Text(
                                                  'Bill ID: ${thread.billId}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                  ),
                                                ),
                                              // Show status description from metadata (populated by backend)
                                              if (thread.statusDescription != null && thread.statusDescription!.isNotEmpty)
                                                ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxWidth: constraints.maxWidth * 0.4,
                                                  ),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).colorScheme.primaryContainer,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      thread.statusDescription!,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                )
                                              // Fallback: show statusID if description not available
                                              else if (thread.billStatusID != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).colorScheme.surfaceVariant,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'Status: ${thread.billStatusID}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
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
            ),
          ],
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

