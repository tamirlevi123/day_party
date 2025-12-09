import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/thread_provider.dart';
import '../widgets/user_profile_action.dart';

class ThreadListScreen extends StatelessWidget {
  final String topicId;

  const ThreadListScreen({super.key, required this.topicId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThreadProvider()..loadThreads(topicId),
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

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.threads.length,
              itemBuilder: (context, index) {
                final thread = provider.threads[index];
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
                            child: Text(
                              thread.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
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

