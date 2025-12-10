import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/thread_service.dart';
import '../models/thread.dart';
import '../models/node.dart';
import '../providers/auth_provider.dart';
import '../widgets/user_profile_action.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/html_content_widget.dart';
import '../widgets/external_video_card.dart';
import 'login_screen.dart';
import 'package:omni_video_player/omni_video_player.dart';

class ThreadDetailScreen extends StatefulWidget {
	final String threadId;
	const ThreadDetailScreen({super.key, required this.threadId});

	@override
	State<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<ThreadDetailScreen> {
	final _service = ThreadService();
	Future<ThreadDetailResponse>? _future;
	String? _selectedNodeId; // Track the currently selected node (null = root)

	/// Parse textFormat string to TextFormat enum
	TextFormat? _parseTextFormat(String format) {
		switch (format.toLowerCase()) {
			case 'plain':
				return TextFormat.plain;
			case 'markdown':
				return TextFormat.markdown;
			case 'html':
				return TextFormat.html;
			case 'delta':
				return TextFormat.delta;
			default:
				return null;
		}
	}

	@override
	void initState() {
		super.initState();
		_future = _service.getThread(widget.threadId);
		_selectedNodeId = null; // Start with root node
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Thread'),
				actions: const [UserProfileAction()],
			),
			body: FutureBuilder<ThreadDetailResponse>(
				future: _future,
				builder: (context, snapshot) {
					if (snapshot.connectionState == ConnectionState.waiting) {
						return const Center(child: CircularProgressIndicator());
					}
					if (snapshot.hasError) {
						return Center(
							child: Column(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									Text('Error: ${snapshot.error}'),
									const SizedBox(height: 12),
									ElevatedButton(
										onPressed: () => setState(() {
											_future = _service.getThread(widget.threadId);
										}),
										child: const Text('Retry'),
									),
								],
							),
						);
					}
					final data = snapshot.data!;
					
					// Check if there are any nodes
					if (data.nodes.isEmpty) {
						// Show thread description if available, otherwise show empty state
						return SingleChildScrollView(
							child: Padding(
								padding: const EdgeInsets.all(16.0),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											data.thread.title,
											style: const TextStyle(
												fontSize: 24,
												fontWeight: FontWeight.bold,
											),
										),
										if (data.thread.description != null) ...[
											const SizedBox(height: 16),
											HtmlContentWidget(
												content: data.thread.description!,
												textStyle: const TextStyle(fontSize: 16),
											),
										],
										const SizedBox(height: 24),
										const Center(
											child: Text(
												'No posts yet. Be the first to reply!',
												style: TextStyle(
													fontSize: 16,
													color: Colors.grey,
												),
											),
										),
										const SizedBox(height: 16),
										Center(
											child: ElevatedButton.icon(
												onPressed: () {
													final authProvider = Provider.of<AuthProvider>(context, listen: false);
													if (!authProvider.isLoggedIn) {
														showDialog(
															context: context,
															builder: (context) => AlertDialog(
																title: const Text('נדרשת התחברות'),
																content: const Text('עליך להתחבר כדי להשאיר תגובה.'),
																actions: [
																	TextButton(
																		onPressed: () => Navigator.pop(context),
																		child: const Text('ביטול'),
																	),
																	ElevatedButton(
																		onPressed: () {
																			Navigator.pop(context);
																			Navigator.push(
																				context,
																				MaterialPageRoute(
																					builder: (_) => const LoginScreen(),
																				),
																			);
																		},
																		child: const Text('התחבר'),
																	),
																],
															),
														);
														return;
													}
													Navigator.pushNamed(
														context,
														'/create-node',
														arguments: {
															'threadId': data.thread.threadId,
															'parentNodeId': null,
														},
													).then((success) {
														if (success == true && mounted) {
															setState(() {
																_future = _service.getThread(widget.threadId);
															});
														}
													});
												},
												icon: const Icon(Icons.add_comment),
												label: const Text('הוסף תגובה ראשונה'),
											),
										),
									],
								),
							),
						);
					}
					
					// Find root node (node with no parent)
					final rootNode = data.nodes.firstWhere(
						(n) => n.parentNodeId == null,
						orElse: () => data.nodes.first, // Fallback to first node if no root found
					);
					
					// Get the currently selected node (or root if none selected)
					final selectedNode = _selectedNodeId != null
						? data.nodes.firstWhere((n) => n.nodeId == _selectedNodeId, orElse: () => rootNode)
						: rootNode;
					
					// Get all nodes for building the tree path
					final allNodes = data.nodes;
					
					// Build breadcrumb path (from root to selected node) with relations
					// Each item shows the node and its relation to its parent
					List<({Node node, String? relation})> buildBreadcrumb(Node node) {
						if (node.parentNodeId == null) {
							// Root node has no parent, so no relation
							return [(node: node, relation: null)];
						}
						final parent = allNodes.firstWhere((n) => n.nodeId == node.parentNodeId);
						final parentBreadcrumb = buildBreadcrumb(parent);
						// Get the relation of current node to its parent (this is stored on the node)
						final relation = node.parentRelation;
						return [...parentBreadcrumb, (node: node, relation: relation)];
					}
					
					final breadcrumb = _selectedNodeId != null ? buildBreadcrumb(selectedNode) : [(node: rootNode, relation: null)];
					
					// Filter replies to show only direct children of selected node
					final replies = data.nodes
						.where((n) => n.parentNodeId == selectedNode.nodeId)
						.toList()
						..sort((a, b) {
							// Sort: PRO first, AGAINST second, NEUTRAL third
							final order = {'pro': 0, 'against': 1, 'neutral': 2, null: 3};
							final aOrder = order[a.parentRelation?.toLowerCase()] ?? 3;
							final bOrder = order[b.parentRelation?.toLowerCase()] ?? 3;
							return aOrder.compareTo(bOrder);
						});

					// Helper function to count replies for a node
					int getReplyCount(String nodeId) {
						return data.nodes.where((n) => n.parentNodeId == nodeId).length;
					}

					return Column(
						children: [
							// Breadcrumb navigation (if not at root)
							if (_selectedNodeId != null && breadcrumb.length > 1) ...[
								Container(
									padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
									color: Colors.grey.shade100,
									child: Column(
										children: [
											// One title per line with color coding
											...breadcrumb.asMap().entries.map((entry) {
												final index = entry.key;
												final item = entry.value;
												final node = item.node;
												final relation = item.relation;
												final isLast = index == breadcrumb.length - 1;
												
												// Determine color based on relation (relation color takes priority)
												Color getTitleColor() {
													// First check relation - this determines the color
													if (relation != null) {
														switch (relation.toLowerCase()) {
															case 'pro':
																return Colors.green;
															case 'against':
																return Colors.red;
															case 'neutral':
																return Colors.grey;
															default:
																return Colors.grey.shade700;
														}
													}
													// If no relation (root node), use grey
													return Colors.grey.shade700;
												}
												
												return GestureDetector(
													onTap: isLast ? null : () {
														setState(() {
															_selectedNodeId = node.nodeId == rootNode.nodeId ? null : node.nodeId;
														});
													},
													child: Padding(
														padding: const EdgeInsets.symmetric(vertical: 2),
														child: Row(
															children: [
																if (index > 0)
																	const Padding(
																		padding: EdgeInsets.only(right: 8),
																		child: Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
																	),
																Expanded(
																	child: Text(
																		node.title,
																		style: TextStyle(
																			color: getTitleColor(),
																			fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
																			fontSize: 13,
																		),
																		maxLines: 2,
																		overflow: TextOverflow.ellipsis,
																	),
																),
															],
														),
													),
												);
											}),
										],
									),
								),
							],
							
							// Scrollable content area (main node + replies)
							Expanded(
								child: SingleChildScrollView(
									child: Column(
										children: [
											// Main selected node display (prominently at top)
											Padding(
												padding: const EdgeInsets.all(16),
												child: Card(
													elevation: _selectedNodeId != null ? 4 : 2,
													color: _selectedNodeId != null ? Colors.blue.shade50 : null,
													child: Padding(
														padding: const EdgeInsets.all(16),
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Row(
																	children: [
																		Expanded(
																			child: Text(
																				selectedNode.title,
																				style: TextStyle(
																					fontSize: _selectedNodeId != null ? 22 : 20,
																					fontWeight: FontWeight.bold,
																				),
																			),
																		),
																		if (_selectedNodeId != null)
																			Container(
																				padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
																				decoration: BoxDecoration(
																					color: Colors.blue,
																					borderRadius: BorderRadius.circular(12),
																				),
																				child: const Text(
																					'נבחר',
																					style: TextStyle(
																						color: Colors.white,
																						fontSize: 10,
																						fontWeight: FontWeight.bold,
																					),
																				),
																			),
																	],
																),
																const SizedBox(height: 8),
																if (selectedNode.textContent != null)
																	HtmlContentWidget(
																		content: selectedNode.textContent!,
																		textStyle: const TextStyle(fontSize: 14),
																		format: selectedNode.textFormat != null 
																			? _parseTextFormat(selectedNode.textFormat!)
																			: null,
																	),
																if (selectedNode.video != null) ...[
																	const SizedBox(height: 12),
																	if (selectedNode.video!.source == VideoSource.external)
																		ExternalVideoCard(attachment: selectedNode.video!)
																	else
																		VideoPlayerWidget(
																			urlOrPath: selectedNode.video!.url ?? '',
																			height: 220,
																		),
																] else if (selectedNode.legacyVideoUrl != null) ...[
																	const SizedBox(height: 12),
																	VideoPlayerWidget(urlOrPath: selectedNode.legacyVideoUrl!, height: 220),
																],
																const SizedBox(height: 16),
																Row(
																	mainAxisAlignment: MainAxisAlignment.spaceAround,
																	children: [
																		Column(
																			children: [
																				IconButton(
																					icon: const Icon(Icons.thumb_up),
																					onPressed: () {},
																					tooltip: 'Like',
																				),
																				Text('${selectedNode.voteTallies.like}'),
																			],
																		),
																		Column(
																			children: [
																				IconButton(
																					icon: const Icon(Icons.thumb_down),
																					onPressed: () {},
																					tooltip: 'Dislike',
																				),
																				Text('${selectedNode.voteTallies.dislike}'),
																			],
																		),
																	],
																),
																const SizedBox(height: 16),
																Row(
																	mainAxisAlignment: MainAxisAlignment.spaceBetween,
																	children: [
																		if (replies.isNotEmpty)
																			Text(
																				'${replies.length} תגובות ישירות',
																				style: TextStyle(
																					fontSize: 14,
																					color: Colors.grey[700],
																					fontWeight: FontWeight.w500,
																				),
																			)
																		else
																			const SizedBox.shrink(),
																		ElevatedButton.icon(
																			onPressed: () {
																				final authProvider = Provider.of<AuthProvider>(context, listen: false);
																				if (!authProvider.isLoggedIn) {
																					// Show login prompt
																					showDialog(
																						context: context,
																						builder: (context) => AlertDialog(
																							title: const Text('נדרשת התחברות'),
																							content: const Text('עליך להתחבר כדי להשאיר תגובה.'),
																							actions: [
																								TextButton(
																									onPressed: () => Navigator.pop(context),
																									child: const Text('ביטול'),
																								),
																								ElevatedButton(
																									onPressed: () {
																										Navigator.pop(context);
																										Navigator.push(
																											context,
																											MaterialPageRoute(
																												builder: (_) => const LoginScreen(),
																											),
																										);
																									},
																									child: const Text('התחבר'),
																								),
																							],
																						),
																					);
																					return;
																				}
																				Navigator.pushNamed(
																					context,
																					'/create-node',
																					arguments: {
																						'threadId': data.thread.threadId,
																						'parentNodeId': selectedNode.nodeId,
																					},
																				).then((success) {
																					if (success == true && mounted) {
																						// Reload thread after successful reply
																						setState(() {
																							_future = _service.getThread(widget.threadId);
																						});
																					}
																				});
																			},
																			icon: const Icon(Icons.reply),
																			label: const Text('תגובה'),
																		),
																	],
																),
															],
														),
													),
												),
											),

											// Replies section
											if (replies.isNotEmpty) ...[
												const SizedBox(height: 8),
												const Center(
													child: Text(
														'טיעונים',
														style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
													),
												),
												const SizedBox(height: 8),
												...replies.map((node) {
													return Padding(
														padding: const EdgeInsets.symmetric(horizontal: 16),
														child: Card(
															margin: const EdgeInsets.only(bottom: 12),
															elevation: 1,
															child: InkWell(
																onTap: () {
																	// Clicking a reply makes it the main display
																	setState(() {
																		_selectedNodeId = node.nodeId;
																	});
																},
																child: Padding(
																	padding: const EdgeInsets.all(12),
																	child: Column(
																		crossAxisAlignment: CrossAxisAlignment.start,
																		children: [
																			Row(
																				children: [
																					if (node.parentRelation != null)
																						Container(
																						padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
																						decoration: BoxDecoration(
																							color: _getRelationColor(node.parentRelation!),
																							borderRadius: BorderRadius.circular(4),
																						),
																						child: Text(
																							node.parentRelation!.toUpperCase(),
																							style: const TextStyle(
																								color: Colors.white,
																								fontSize: 12,
																								fontWeight: FontWeight.bold,
																							),
																						),
																					),
																					const SizedBox(width: 8),
																					Text(
																						node.author?.displayName ?? 'Anonymous',
																						style: const TextStyle(fontWeight: FontWeight.bold),
																					),
																					const Spacer(),
																					if (getReplyCount(node.nodeId) > 0)
																						Row(
																							children: [
																								Text(
																									'${getReplyCount(node.nodeId)}',
																									style: TextStyle(
																										fontSize: 12,
																										color: Colors.grey[700],
																										fontWeight: FontWeight.w500,
																									),
																								),
																								const SizedBox(width: 4),
																								Icon(
																									Icons.arrow_forward_ios,
																									size: 14,
																									color: Colors.grey[600],
																								),
																							],
																						),
																				],
																			),
																	const SizedBox(height: 8),
																	Text(
																		node.title,
																		style: const TextStyle(fontWeight: FontWeight.w600),
																	),
																	if (node.textContent != null) ...[
																		const SizedBox(height: 4),
																		HtmlContentWidget(
																			content: node.textContent!,
																			textStyle: const TextStyle(fontSize: 14),
																			format: node.textFormat != null 
																				? _parseTextFormat(node.textFormat!)
																				: null,
																		),
																	],
																	if (node.video != null) ...[
																		const SizedBox(height: 8),
																		GestureDetector(
																			onTap: () {
																				// Stop tap from propagating to parent InkWell
																				// The video/iframe will handle its own interactions
																			},
																			behavior: HitTestBehavior.opaque,
																			child: node.video!.source == VideoSource.external
																				? (node.video!.provider == 'youtube'
																					? _buildOmniVideoPlayerTest(node.video!)
																					: ExternalVideoCard(attachment: node.video!))
																				: VideoPlayerWidget(
																					urlOrPath: node.video!.url ?? '',
																					height: 180,
																				),
																		),
																	] else if (node.legacyVideoUrl != null) ...[
																		const SizedBox(height: 8),
																		GestureDetector(
																			onTap: () {
																				// Stop tap from propagating to parent InkWell
																			},
																			behavior: HitTestBehavior.opaque,
																			child: VideoPlayerWidget(urlOrPath: node.legacyVideoUrl!, height: 180),
																		),
																	],
																	const SizedBox(height: 12),
																	Row(
																		mainAxisAlignment: MainAxisAlignment.spaceAround,
																		children: [
																			Row(
																				children: [
																					IconButton(
																						icon: const Icon(Icons.thumb_up, size: 20),
																						onPressed: () {},
																						tooltip: 'Like',
																					),
																					Text('${node.voteTallies.like}'),
																				],
																			),
																			Row(
																				children: [
																					Text('${node.voteTallies.dislike}'),
																					IconButton(
																						icon: const Icon(Icons.thumb_down, size: 20),
																						onPressed: () {},
																						tooltip: 'Dislike',
																					),
																				],
																			),
																			Row(
																				children: [
																					IconButton(
																						icon: const Icon(Icons.reply, size: 20),
																						onPressed: () {
																							final authProvider = Provider.of<AuthProvider>(context, listen: false);
																							if (!authProvider.isLoggedIn) {
																								// Show login prompt
																								showDialog(
																									context: context,
																									builder: (context) => AlertDialog(
																										title: const Text('נדרשת התחברות'),
																										content: const Text('עליך להתחבר כדי להשאיר תגובה.'),
																										actions: [
																											TextButton(
																												onPressed: () => Navigator.pop(context),
																												child: const Text('ביטול'),
																											),
																											ElevatedButton(
																												onPressed: () {
																													Navigator.pop(context);
																													Navigator.push(
																														context,
																														MaterialPageRoute(
																															builder: (_) => const LoginScreen(),
																														),
																													);
																												},
																												child: const Text('התחבר'),
																											),
																										],
																									),
																								);
																								return;
																							}
																							Navigator.pushNamed(
																								context,
																								'/create-node',
																								arguments: {
																									'threadId': node.threadId,
																									'parentNodeId': node.nodeId,
																								},
																							).then((success) {
																								if (success == true && mounted) {
																									setState(() {
																										_future = _service.getThread(widget.threadId);
																									});
																								}
																							});
																						},
																						tooltip: 'Reply',
																					),
																				],
																			),
																		],
																	),
																],
																	),
																),
															),
														),
													);
												}).toList(),
											],
										],
									),
								),
							),
						],
					);
				},
			),
		);
	}

	Color _getRelationColor(String relation) {
		switch (relation.toLowerCase()) {
			case 'pro':
				return Colors.green;
			case 'against':
				return Colors.red;
			case 'neutral':
				return Colors.grey;
			default:
				return Colors.grey;
		}
	}

	/// TEST: Hardcoded omni_video_player test widget for YouTube videos
	Widget _buildOmniVideoPlayerTest(VideoAttachment attachment) {
		// Extract video ID from providerId or URL
		String? videoId = attachment.providerId;
		if (videoId == null || videoId.isEmpty) {
			// Try to extract from URL
			final url = attachment.url ?? '';
			final match = RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([a-zA-Z0-9_-]+)').firstMatch(url);
			videoId = match?.group(1);
		}

		if (videoId == null || videoId.isEmpty) {
			// Fallback to ExternalVideoCard if we can't extract video ID
			return ExternalVideoCard(attachment: attachment);
		}

		// Build YouTube URL
		final youtubeUrl = Uri.parse('https://www.youtube.com/watch?v=$videoId');

		return Container(
			height: 200,
			margin: const EdgeInsets.symmetric(vertical: 8),
			decoration: BoxDecoration(
				color: Colors.black,
				borderRadius: BorderRadius.circular(12),
			),
			child: ClipRRect(
				borderRadius: BorderRadius.circular(12),
				child: OmniVideoPlayer(
					callbacks: VideoPlayerCallbacks(
						onControllerCreated: (controller) {
							// Controller created
						},
						onFullScreenToggled: (isFullScreen) {},
						onOverlayControlsVisibilityChanged: (areVisible) {},
						onCenterControlsVisibilityChanged: (areVisible) {},
						onMuteToggled: (isMute) {},
						onSeekStart: (pos) {},
						onSeekEnd: (pos) {},
						onSeekRequest: (target) => true,
						onFinished: () {},
						onReplay: () {},
					),
					options: VideoPlayerConfiguration(
						videoSourceConfiguration: VideoSourceConfiguration.youtube(
							videoUrl: youtubeUrl,
							preferredQualities: const [
								OmniVideoQuality.high720,
								OmniVideoQuality.medium480,
							],
							availableQualities: const [
								OmniVideoQuality.high1080,
								OmniVideoQuality.high720,
								OmniVideoQuality.medium480,
								OmniVideoQuality.medium360,
							],
							enableYoutubeWebViewFallback: true,
							forceYoutubeWebViewOnly: false,
						).copyWith(
							autoPlay: false,
							initialPosition: Duration.zero,
							initialVolume: 1.0,
							initialPlaybackSpeed: 1.0,
							autoMuteOnStart: false,
							allowSeeking: true,
						),
						playerUIVisibilityOptions: PlayerUIVisibilityOptions().copyWith(
							showSeekBar: true,
							showCurrentTime: true,
							showDurationTime: true,
							showPlayPauseReplayButton: true,
							showFullScreenButton: true,
							showMuteUnMuteButton: true,
						),
					),
				),
			),
		);
	}
}
