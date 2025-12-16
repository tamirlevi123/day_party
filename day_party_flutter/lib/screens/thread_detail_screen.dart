import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
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
import '../providers/knesset/knesset_database_provider.dart';
import '../providers/memes_provider.dart';
import '../models/knesset/knesset_document_bill.dart';
import '../widgets/knesset_document_viewer.dart';
import '../widgets/meme_card.dart';
import '../widgets/zoomable_image_viewer.dart';
import '../core/logger.dart';
import '../core/api_client.dart';
import 'dart:convert';

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

	/// Extract image URL from Delta JSON or HTML content (same logic as MemeCard)
	String? _extractImageUrlFromContent(String content, String? format) {
		try {
			String? htmlContent;
			
			// If it's Delta format, parse it to extract HTML
			if (format == 'delta' || format == null) {
				try {
					String contentToParse = content;
					
					// Handle double-encoded JSON strings
					if (content.trim().startsWith('"') && content.trim().endsWith('"')) {
						contentToParse = jsonDecode(content) as String;
					}
					
					final decoded = jsonDecode(contentToParse);
					List<dynamic> ops;
					
					if (decoded is List) {
						ops = decoded;
					} else if (decoded is Map<String, dynamic>) {
						ops = decoded['ops'] as List<dynamic>? ?? [];
					} else {
						return null;
					}
					
					// Extract HTML from Delta ops
					for (final op in ops) {
						if (op is Map && op.containsKey('insert')) {
							final insert = op['insert'];
							if (insert is String && insert.contains('<img')) {
								htmlContent = insert;
								break;
							}
						}
					}
				} catch (e) {
					appLogger.e('Error parsing Delta JSON for image', error: e);
					return null;
				}
			} else if (format == 'html' || content.contains('<img')) {
				htmlContent = content;
			}
			
			// Extract image URL from HTML using regex
			if (htmlContent != null) {
				// Normalize HTML: remove newlines and extra whitespace
				final normalizedHtml = htmlContent.replaceAll(RegExp(r'\s+'), ' ');
				
				// Try double quotes first
				final regexDoubleQuote = RegExp(r'<img[^>]*src\s*=\s*"([^"]+)"', caseSensitive: false, dotAll: true);
				var match = regexDoubleQuote.firstMatch(normalizedHtml);
				
				// If not found, try single quotes
				if (match == null) {
					final regexSingleQuote = RegExp(r"<img[^>]*src\s*=\s*'([^']+)'", caseSensitive: false, dotAll: true);
					match = regexSingleQuote.firstMatch(normalizedHtml);
				}
				
				if (match != null && match.groupCount >= 1) {
					var imageUrl = match.group(1);
					if (imageUrl != null && imageUrl.isNotEmpty) {
						// If it's already an absolute URL, extract the path and reconstruct
						if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
							final uri = Uri.tryParse(imageUrl);
							if (uri != null) {
								var path = uri.path;
								if (uri.hasQuery) {
									path += '?${uri.query}';
								}
								return _makeAbsoluteUrl(path);
							}
						}
						
						// If it's a relative URL, make it absolute
						return _makeAbsoluteUrl(imageUrl);
					}
				}
				
				// Fallback: try without quotes
				final regexNoQuotes = RegExp(r'<img[^>]*src\s*=\s*([^\s>]+)', caseSensitive: false, dotAll: true);
				final matchNoQuotes = regexNoQuotes.firstMatch(normalizedHtml);
				if (matchNoQuotes != null && matchNoQuotes.groupCount >= 1) {
					final imageUrl = matchNoQuotes.group(1);
					if (imageUrl != null && imageUrl.isNotEmpty) {
						return _makeAbsoluteUrl(imageUrl);
					}
				}
			}
		} catch (e, stackTrace) {
			appLogger.e('Error extracting image URL', error: e, stackTrace: stackTrace);
		}
		
		return null;
	}

	/// Convert relative URL to absolute URL (same logic as MemeCard)
	String _makeAbsoluteUrl(String url) {
		if (url.startsWith('http://') || url.startsWith('https://')) {
			return url;
		}
		
		// Get base URL from API client (includes /api)
		final apiBaseUrl = ApiClient.baseUrl;
		
		// Remove /api suffix since images are served from root, not /api
		String baseUrl = apiBaseUrl;
		if (baseUrl.endsWith('/api')) {
			baseUrl = baseUrl.substring(0, baseUrl.length - 4);
		} else if (baseUrl.endsWith('/api/')) {
			baseUrl = baseUrl.substring(0, baseUrl.length - 5);
		}
		
		// Remove trailing slash from baseUrl and leading slash from url if present
		final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
		final cleanUrl = url.startsWith('/') ? url : '/$url';
		
		return '$cleanBaseUrl$cleanUrl';
	}

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
																	Consumer<MemesProvider>(
																		builder: (context, memesProvider, _) {
																			// For memes topic, try to extract and display image directly
																			if (memesProvider.isMemesTopic(data.thread.topicId)) {
																				// Use MemeCard's extraction logic to get image URL
																				final imageUrl = _extractImageUrlFromContent(
																					selectedNode.textContent!,
																					selectedNode.textFormat,
																				);
																				if (imageUrl != null) {
																					return ClipRRect(
																						borderRadius: BorderRadius.circular(8),
																						child: GestureDetector(
																							onTap: () {
																								// Navigate to zoomable image viewer
																								Navigator.push(
																									context,
																									MaterialPageRoute(
																										builder: (context) => ZoomableImageViewer(
																											imageUrl: imageUrl,
																											title: selectedNode.title,
																										),
																									),
																								);
																							},
																							child: Hero(
																								tag: imageUrl,
																								child: Image.network(
																									imageUrl,
																									fit: BoxFit.contain,
																									loadingBuilder: (context, child, loadingProgress) {
																										if (loadingProgress == null) return child;
																										return Center(
																											child: CircularProgressIndicator(
																												value: loadingProgress.expectedTotalBytes != null
																													? loadingProgress.cumulativeBytesLoaded /
																														loadingProgress.expectedTotalBytes!
																													: null,
																											),
																										);
																									},
																									errorBuilder: (context, error, stackTrace) {
																										appLogger.e('Error loading meme image', error: error, stackTrace: stackTrace);
																										return Container(
																											height: 200,
																											color: Colors.grey[300],
																											child: Center(
																												child: Column(
																													mainAxisAlignment: MainAxisAlignment.center,
																													children: [
																														Icon(Icons.broken_image, size: 48, color: Colors.grey[600]),
																														const SizedBox(height: 8),
																														Text(
																															'לא ניתן לטעון את התמונה',
																															style: TextStyle(color: Colors.grey[600]),
																														),
																													],
																												),
																											),
																										);
																									},
																								),
																							),
																						),
																					);
																				}
																			}
																			// Fallback to HtmlContentWidget for non-memes or if image extraction failed
																			return HtmlContentWidget(
																				content: selectedNode.textContent!,
																				textStyle: const TextStyle(fontSize: 14),
																				format: selectedNode.textFormat != null 
																					? _parseTextFormat(selectedNode.textFormat!)
																					: null,
																			);
																		},
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
																// Voting buttons - hide for memes
																Consumer<MemesProvider>(
																	builder: (context, memesProvider, _) {
																		if (memesProvider.isMemesTopic(data.thread.topicId)) {
																			// Memes are display-only: no voting
																			return const SizedBox.shrink();
																		}
																		return Row(
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
																		);
																	},
																),
																const SizedBox(height: 16),
																// Reply button - hide for memes (moved above docs)
																Consumer<MemesProvider>(
																	builder: (context, memesProvider, _) {
																		if (memesProvider.isMemesTopic(data.thread.topicId)) {
																			// Memes are display-only: no replies
																			return const SizedBox.shrink();
																		}
																		return Padding(
																			padding: const EdgeInsets.only(bottom: 16),
																			child: Row(
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
																		);
																	},
																),
																// Show Knesset documents if this is the root node (after response button)
																if (selectedNode.parentNodeId == null && _selectedNodeId == null) ...[
																	_buildKnessetDocuments(data.thread, selectedNode),
																],
															],
														),
													),
												),
											),

											// Replies section - hide for memes
											Consumer<MemesProvider>(
												builder: (context, memesProvider, _) {
													if (memesProvider.isMemesTopic(data.thread.topicId)) {
														// Memes are display-only: no replies shown
														return const SizedBox.shrink();
													}
													if (replies.isEmpty) {
														return const SizedBox.shrink();
													}
													return Column(
														children: [
															const SizedBox(height: 8),
															const Center(
																child: Text(
																	'טיעונים',
																	style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
																),
															),
															const SizedBox(height: 8),
															Consumer<MemesProvider>(
													builder: (context, memesProvider, _) {
														// Show a meme every 4 replies
														const memeInterval = 4;
														final widgets = <Widget>[];
														// Create a Random instance for this build cycle to randomly select memes
														final random = Random();

														for (int i = 0; i < replies.length; i++) {
															final node = replies[i];
															
															// Add reply widget
															widgets.add(
																Padding(
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
																								onTap: () {},
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
																),
															);
															
															// Add meme after every 4th reply (if not the last reply)
															if ((i + 1) % memeInterval == 0 && 
																i < replies.length - 1 && 
																memesProvider.hasMemes) {
																// Randomly select a meme for this position
																final meme = memesProvider.getRandomMeme(random);
																if (meme != null) {
																	widgets.add(MemeCard(memeThread: meme));
																}
															}
														}
														
														return Column(children: widgets);
													},
												),
														],
													);
												},
											),
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
	/// Build Knesset documents widget for root node
	Widget _buildKnessetDocuments(Thread thread, Node rootNode) {
		appLogger.d('_buildKnessetDocuments called for node ${rootNode.nodeId}');
		appLogger.d('Root node metadata: ${rootNode.metadata}');
		
		// Extract BillID from root node metadata
		final billId = _getBillIdFromMetadata(rootNode);
		appLogger.d('Extracted billId: $billId');
		
		if (billId == null) {
			appLogger.d('No billId found, returning empty widget');
			return const SizedBox.shrink(); // Not a Knesset bill
		}
		
		appLogger.d('Building documents widget for billId: $billId');
		
		return Consumer<KnessetDatabaseProvider>(
			builder: (context, knessetProvider, _) {
				appLogger.d('Consumer builder called, fetching documents for billId: $billId');
				return FutureBuilder<List<KnessetDocumentBill>>(
					future: _getDocumentsForBill(billId, knessetProvider),
					builder: (context, documentsSnapshot) {
						appLogger.d('FutureBuilder state: ${documentsSnapshot.connectionState}, hasError: ${documentsSnapshot.hasError}, hasData: ${documentsSnapshot.hasData}');
						
						if (documentsSnapshot.connectionState == ConnectionState.waiting) {
							appLogger.d('Loading documents for billId: $billId...');
							// Show loading indicator instead of hiding
							return const Padding(
								padding: EdgeInsets.all(8.0),
								child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
							);
						}
						
						if (documentsSnapshot.hasError) {
							appLogger.e('Error loading documents: ${documentsSnapshot.error}', error: documentsSnapshot.error, stackTrace: documentsSnapshot.stackTrace);
							return Padding(
								padding: const EdgeInsets.all(8.0),
								child: Text('שגיאה בטעינת מסמכים: ${documentsSnapshot.error}'),
							);
						}
						
						final documents = documentsSnapshot.data ?? [];
						appLogger.d('Documents loaded: ${documents.length} for billId: $billId');
						if (documents.isEmpty) {
							appLogger.d('No documents found for billId: $billId');
							return const SizedBox.shrink();
						}
						
						return Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								const SizedBox(height: 16),
								const Divider(),
								const SizedBox(height: 8),
								Text(
									'מסמכים קשורים',
									style: Theme.of(context).textTheme.titleMedium?.copyWith(
										fontWeight: FontWeight.bold,
									),
								),
								const SizedBox(height: 8),
								...documents.map((doc) => _buildDocumentTile(doc)),
							],
						);
					},
				);
			},
		);
	}

	/// Extract BillID from node metadata
	int? _getBillIdFromMetadata(Node node) {
		if (node.metadata == null) {
			appLogger.d('Node ${node.nodeId} has no metadata');
			return null;
		}
		appLogger.d('Node ${node.nodeId} metadata: ${node.metadata}');
		final billId = node.metadata!['billId'];
		appLogger.d('Extracted billId: $billId (type: ${billId.runtimeType})');
		if (billId is int) return billId;
		if (billId is String) return int.tryParse(billId);
		if (billId is double) return billId.toInt();
		return null;
	}

	/// Get documents for a bill
	Future<List<KnessetDocumentBill>> _getDocumentsForBill(int billId, KnessetDatabaseProvider provider) async {
		try {
			appLogger.d('Fetching documents for billId: $billId');
			final documents = await provider.getDocumentsByBillId(billId);
			appLogger.d('Found ${documents.length} documents for billId: $billId');
			return documents;
		} catch (e, s) {
			appLogger.e('Error fetching documents for bill $billId', error: e, stackTrace: s);
			return [];
		}
	}

	/// Build a document tile widget
	Widget _buildDocumentTile(KnessetDocumentBill doc) {
		final title = doc.groupTypeDesc.isNotEmpty 
			? doc.groupTypeDesc 
			: (doc.fileName?.isNotEmpty ?? false ? doc.fileName! : 'מסמך ללא כותרת');
		final subtitle = (doc.fileName?.isNotEmpty ?? false) && doc.fileName != title
			? doc.fileName
			: null;

		return ListTile(
			leading: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary),
			title: Text(title),
			subtitle: subtitle != null ? Text(subtitle) : null,
			trailing: doc.filePath != null ? const Icon(Icons.open_in_new) : null,
			onTap: doc.filePath != null 
				? () => KnessetDocumentViewer.show(context, doc)
				: null,
			enabled: doc.filePath != null,
		);
	}

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
