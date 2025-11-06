import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../widgets/user_profile_action.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Load topics when screen is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HomeProvider>(context, listen: false).loadTopics();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day Party'),
        actions: [
          const UserProfileAction(),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Navigate to notifications
            },
          ),
        ],
      ),
      body: Consumer<HomeProvider>(
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
                    onPressed: () => provider.loadTopics(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.topics.isEmpty) {
            return const Center(
              child: Text('No topics available'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.topics.length,
            itemBuilder: (context, index) {
              final topic = provider.topics[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.folder, size: 32),
                  title: Text(
                    topic.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text('${topic.threadCount} active threads'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to thread list
                    Navigator.pushNamed(context, '/threads', arguments: topic.topicId);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

