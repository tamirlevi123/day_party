-- MySQL dump 10.13  Distrib 8.0.44, for Win64 (x86_64)
--
-- Host: localhost    Database: dayparty
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `modality_generation_jobs`
--

DROP TABLE IF EXISTS `modality_generation_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `modality_generation_jobs` (
  `id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUID primary key',
  `node_id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Reference to nodes.id',
  `target_modality` enum('text','video') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Modality to generate',
  `source` enum('ai','human') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Generation source (AI or human)',
  `status` enum('queued','in_progress','succeeded','failed') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Job status',
  `requested_by` char(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'User who requested generation',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Job creation timestamp',
  `completed_at` datetime DEFAULT NULL COMMENT 'Job completion timestamp',
  `notes` text COLLATE utf8mb4_unicode_ci COMMENT 'Notes or error messages',
  PRIMARY KEY (`id`),
  KEY `idx_modality_jobs_node_modality` (`node_id`,`target_modality`),
  KEY `idx_modality_jobs_status` (`status`),
  KEY `fk_modality_jobs_requested_by` (`requested_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Background jobs for generating missing text/video modalities';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `modality_generation_jobs`
--

LOCK TABLES `modality_generation_jobs` WRITE;
/*!40000 ALTER TABLE `modality_generation_jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `modality_generation_jobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_versions`
--

DROP TABLE IF EXISTS `node_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_versions` (
  `id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUID primary key',
  `node_id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Reference to nodes.id',
  `version_number` int NOT NULL COMMENT 'Version number (1-based incremental)',
  `title` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Title at this version',
  `text_content` text COLLATE utf8mb4_unicode_ci COMMENT 'Text content at this version',
  `text_format` enum('markdown','plain') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Text format',
  `video_url` varchar(2048) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Video URL at this version',
  `video_duration_sec` int DEFAULT NULL COMMENT 'Video duration',
  `video_thumbnail_url` varchar(2048) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Video thumbnail URL',
  `text_language` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Text language',
  `text_confidence` decimal(5,4) DEFAULT NULL COMMENT 'Confidence score',
  `text_status` enum('provided','generated','missing') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Text status',
  `video_status` enum('provided','generated','missing') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Video status',
  `moderation_state` enum('visible','limited','hidden','removed') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Moderation state',
  `edited_by` char(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'User who made this edit (uploader or admin)',
  `edited_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Edit timestamp',
  `change_summary` text COLLATE utf8mb4_unicode_ci COMMENT 'Summary of changes in this version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_node_versions_node_version` (`node_id`,`version_number`),
  KEY `idx_node_versions_node_id` (`node_id`,`version_number` DESC),
  KEY `fk_node_versions_edited_by` (`edited_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Immutable version history for nodes (for auditability and change notifications)';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_versions`
--

LOCK TABLES `node_versions` WRITE;
/*!40000 ALTER TABLE `node_versions` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_versions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_votes`
--

DROP TABLE IF EXISTS `node_votes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_votes` (
  `id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUID primary key',
  `node_id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Reference to nodes.id',
  `user_id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Voter user ID',
  `type` enum('like','dislike','abstain') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Vote type',
  `is_public` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Whether vote visibility is public',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Vote creation timestamp',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_node_votes_node_user` (`node_id`,`user_id`) COMMENT 'One vote per user per node',
  KEY `idx_node_votes_node_id` (`node_id`),
  KEY `idx_node_votes_user_id` (`user_id`),
  KEY `idx_node_votes_node_public` (`node_id`,`is_public`) COMMENT 'For public voter lists'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='User votes on nodes (like/dislike/abstain) with per-vote visibility control';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_votes`
--

LOCK TABLES `node_votes` WRITE;
/*!40000 ALTER TABLE `node_votes` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_votes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nodes`
--

DROP TABLE IF EXISTS `nodes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nodes` (
  `id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUID primary key',
  `thread_id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Reference to threads.id',
  `parent_node_id` char(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Parent node for tree structure (NULL = root)',
  `parent_relation` enum('pro','against','neutral') COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Relation to parent node (PRO/AGAINST/NEUTRAL). NULL for root nodes.',
  `title` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Node title',
  `text_content` text COLLATE utf8mb4_unicode_ci COMMENT 'Rich text content',
  `text_format` enum('markdown','plain','html') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'plain',
  `video_url` varchar(2048) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Video storage URL/location',
  `video_duration_sec` int DEFAULT NULL COMMENT 'Video duration in seconds',
  `video_thumbnail_url` varchar(2048) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Video thumbnail URL',
  `text_language` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Detected language (e.g., he, en)',
  `text_confidence` decimal(5,4) DEFAULT NULL COMMENT 'Confidence score if generated/transcribed (0-1)',
  `text_status` enum('provided','generated','missing') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'missing' COMMENT 'Text source status',
  `video_status` enum('provided','generated','missing') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'missing' COMMENT 'Video source status',
  `moderation_state` enum('visible','limited','hidden','removed') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'visible' COMMENT 'Moderation visibility state',
  `is_anonymous` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Whether node is anonymous',
  `author_id` char(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Author user ID (nullable for anonymous nodes)',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Soft delete flag',
  `voting_enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Whether voting is enabled on this node',
  `voting_closes_at` datetime DEFAULT NULL COMMENT 'Voting deadline (root nodes only)',
  `voting_required_quorum` int DEFAULT NULL COMMENT 'Minimum votes required (informational, not enforced)',
  `voting_default_public` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Default visibility for votes',
  `voting_eligibility_min_account_age_days` int DEFAULT NULL COMMENT 'Minimum account age to vote (if set)',
  `like_count` int NOT NULL DEFAULT '0' COMMENT 'Cached like vote count',
  `dislike_count` int NOT NULL DEFAULT '0' COMMENT 'Cached dislike vote count',
  `abstain_count` int NOT NULL DEFAULT '0' COMMENT 'Cached abstain vote count',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Node creation timestamp',
  `edited_at` datetime DEFAULT NULL COMMENT 'Last edit timestamp',
  PRIMARY KEY (`id`),
  KEY `idx_nodes_thread_id` (`thread_id`),
  KEY `idx_nodes_parent_node_id` (`parent_node_id`),
  KEY `idx_nodes_author_id` (`author_id`),
  KEY `idx_nodes_moderation_state` (`moderation_state`),
  KEY `idx_nodes_is_deleted` (`is_deleted`),
  KEY `idx_nodes_voting_closes_at` (`voting_closes_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Nodes form a tree structure for discussions; each node can have text/video and voting';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nodes`
--

LOCK TABLES `nodes` WRITE;
/*!40000 ALTER TABLE `nodes` DISABLE KEYS */;
INSERT INTO `nodes` VALUES ('00dc7594-174e-4065-abf9-5b3120263dbd','081bfc61-0cb4-4a40-8270-7ad5af37f411','3c719b52-c99b-4656-9c98-0e691b9a06ed','pro','הסדרה תקטין פשיעה ותאפשר פיקוח','ברגע שהשוק חוקי – אפשר לפקח על איכות, גיל קנייה, ולצמצם את השוק השחור. המס יחזור לקהילה.','plain',NULL,NULL,NULL,NULL,NULL,'provided','missing','visible',0,'f5ac0dc4-3145-4848-bf0c-72c919d25e4b',0,1,NULL,NULL,0,NULL,0,0,0,'2025-11-03 14:26:43',NULL),('0beffd67-70c5-45cd-8ada-589c9fd194b0','081bfc61-0cb4-4a40-8270-7ad5af37f411','3c719b52-c99b-4656-9c98-0e691b9a06ed','against','יאיר לפיד הוא ממש נגד','הסבר די מתיש על למה יאיר לפיד הוא נודניק','plain','https://drive.google.com/uc?export=view&id=1lcdheLHPgY0WGllIYVVvfjCeXTMIAAtk',NULL,NULL,NULL,NULL,'missing','missing','visible',0,NULL,0,1,NULL,NULL,0,NULL,0,0,0,'2025-11-05 11:24:56',NULL),('1e4f8f59-3177-4648-8127-fc31b74d6bbd','f2688e70-ff08-46dd-805b-bf585bb29936','85f6c017-243a-4b62-93c0-72090c0c4b4e','pro','Pro reply','I agree with this!','plain',NULL,NULL,NULL,NULL,NULL,'provided','missing','visible',0,'2f44cff6-302d-4fed-bd17-d03b873d0759',0,1,NULL,NULL,0,NULL,0,0,0,'2025-11-03 14:26:43',NULL),('373c1d51-0b13-4399-990f-d76d0bec42d0','081bfc61-0cb4-4a40-8270-7ad5af37f411','3c719b52-c99b-4656-9c98-0e691b9a06ed','neutral','ניסוי מדורג עם בקרה','אפשר להתחיל בפיילוט ערים/מחוזות, למדוד נתונים על בריאות ובטיחות, ולהרחיב רק אם המדדים טובים.','plain',NULL,NULL,NULL,NULL,NULL,'provided','missing','visible',0,'1a8a8328-aa53-465d-b1b2-ed5e2ee1456f',0,1,NULL,NULL,0,NULL,0,0,0,'2025-11-03 14:26:43',NULL),('3c719b52-c99b-4656-9c98-0e691b9a06ed','081bfc61-0cb4-4a40-8270-7ad5af37f411',NULL,NULL,'הפיכת קנאביס לחוקי עם מס גבוה – בעד?','רעיון: להסדיר שוק חוקי לקנאביס בדומה לסיגריות, עם מס משמעותי ומנגנוני פיקוח. ההכנסות יופנו לבריאות הציבור וחינוך.','plain',NULL,NULL,NULL,NULL,NULL,'provided','missing','visible',0,'69f76d75-a696-4249-ac82-6997b47e89df',0,1,NULL,NULL,0,NULL,0,0,0,'2025-11-03 14:26:43',NULL),('42d1166e-afa8-45f1-a229-b5eb3ab83acd','081bfc61-0cb4-4a40-8270-7ad5af37f411','3c719b52-c99b-4656-9c98-0e691b9a06ed','against','חשש מעלייה בשימוש בקרב צעירים','למרות מס גבוה, זמינות גבוהה עלולה להעלות שימוש בקרב צעירים. צריך אכיפה וחינוך מקדים.','plain',NULL,NULL,NULL,NULL,NULL,'provided','missing','visible',0,'43f8029f-123f-43f6-a4c6-cb14cf9cbf0f',0,1,NULL,NULL,0,NULL,0,0,0,'2025-11-03 14:26:43',NULL),('79846f14-89f0-427a-9ac2-531a8026f2b8','081bfc61-0cb4-4a40-8270-7ad5af37f411','3c719b52-c99b-4656-9c98-0e691b9a06ed','against','יאיר לפיד נגד לגליזציה','למה יאיר לפיד נגד לגליזציה','plain','/data/user/0/com.dayparty.day_party_flutter/cache/file_picker/1762337597054/יאיר לפיד_  נגד לגליזציה של מריחואנה .mp4',NULL,NULL,NULL,NULL,'missing','missing','visible',0,NULL,0,1,NULL,NULL,0,NULL,0,0,0,'2025-11-05 10:13:55',NULL),('85f6c017-243a-4b62-93c0-72090c0c4b4e','f2688e70-ff08-46dd-805b-bf585bb29936',NULL,NULL,'Root Node: Initial Discussion','This is the root node. It has no parent relation.','plain',NULL,NULL,NULL,NULL,NULL,'provided','missing','visible',0,'2f44cff6-302d-4fed-bd17-d03b873d0759',0,1,NULL,NULL,0,NULL,0,0,0,'2025-11-03 14:26:43',NULL),('adfe1206-666a-41bb-8e96-554ed41924b0','081bfc61-0cb4-4a40-8270-7ad5af37f411','373c1d51-0b13-4399-990f-d76d0bec42d0','against','יש בעיה עם ניסוי מחוזי','קשה מאד לשמור על אזור מסוים שלא יהפוך להיות ה\"ספק של המדינה\"','plain',NULL,NULL,NULL,NULL,NULL,'missing','missing','visible',1,NULL,0,1,NULL,NULL,0,NULL,0,0,0,'2025-11-06 07:18:40',NULL),('db9512e4-8d4a-47e0-8434-49d1591d6be5','f2688e70-ff08-46dd-805b-bf585bb29936','85f6c017-243a-4b62-93c0-72090c0c4b4e','neutral','Neutral reply','I have mixed feelings about this.','plain',NULL,NULL,NULL,NULL,NULL,'provided','missing','visible',0,'2f44cff6-302d-4fed-bd17-d03b873d0759',0,1,NULL,NULL,0,NULL,0,0,0,'2025-11-03 14:26:43',NULL),('e94bb4de-fa7a-4f53-86d0-59716ff37fff','f2688e70-ff08-46dd-805b-bf585bb29936','85f6c017-243a-4b62-93c0-72090c0c4b4e','against','Against reply','I disagree with this.','plain',NULL,NULL,NULL,NULL,NULL,'provided','missing','visible',0,'2f44cff6-302d-4fed-bd17-d03b873d0759',0,1,NULL,NULL,0,NULL,0,0,0,'2025-11-03 14:26:43',NULL),('ee9826b2-7191-42cf-982b-6b72bb4615a2','081bfc61-0cb4-4a40-8270-7ad5af37f411','3c719b52-c99b-4656-9c98-0e691b9a06ed','against','דעת הרופאים','שווה לקרוא את\n<a href=\"https://publichealth.doctorsonly.co.il/2020/08/202082/\">נייר עמדה של איגוד רטפאי הציבור בישראל</a>','plain',NULL,NULL,NULL,NULL,NULL,'missing','missing','visible',0,NULL,0,1,NULL,NULL,0,NULL,0,0,0,'2025-11-05 14:08:49',NULL);
/*!40000 ALTER TABLE `nodes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUID primary key',
  `user_id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Recipient user ID',
  `type` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Notification type (e.g., node_updated, node_reply)',
  `payload_json` json NOT NULL COMMENT 'Notification payload as JSON',
  `is_read` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Read status',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Notification creation timestamp',
  PRIMARY KEY (`id`),
  KEY `idx_notifications_user_read` (`user_id`,`is_read`),
  KEY `idx_notifications_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='User notifications (node updates, replies, moderation, etc.)';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reports`
--

DROP TABLE IF EXISTS `reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reports` (
  `id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUID primary key',
  `target_type` enum('thread','node') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Type of reported content',
  `target_id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'ID of reported thread or node (polymorphic)',
  `reporter_id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'User who created the report',
  `reason` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Report reason/description',
  `status` enum('open','reviewing','resolved','rejected') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'open' COMMENT 'Report status',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Report creation timestamp',
  `resolved_by` char(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Admin who resolved the report',
  `resolved_at` datetime DEFAULT NULL COMMENT 'Resolution timestamp',
  PRIMARY KEY (`id`),
  KEY `idx_reports_target` (`target_type`,`target_id`),
  KEY `idx_reports_status` (`status`),
  KEY `idx_reports_reporter_id` (`reporter_id`),
  KEY `fk_reports_resolved_by` (`resolved_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Content reports for moderation (polymorphic: threads or nodes)';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reports`
--

LOCK TABLES `reports` WRITE;
/*!40000 ALTER TABLE `reports` DISABLE KEYS */;
/*!40000 ALTER TABLE `reports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `threads`
--

DROP TABLE IF EXISTS `threads`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `threads` (
  `id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUID primary key',
  `topic_id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Reference to topics.id',
  `title` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Thread title',
  `description` text COLLATE utf8mb4_unicode_ci COMMENT 'Thread description (optional)',
  `created_by` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'User who created the thread',
  `status` enum('open','closed') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'open' COMMENT 'Thread status',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Thread creation timestamp',
  PRIMARY KEY (`id`),
  KEY `idx_threads_topic_id` (`topic_id`),
  KEY `idx_threads_created_by` (`created_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Discussion threads within topics';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `threads`
--

LOCK TABLES `threads` WRITE;
/*!40000 ALTER TABLE `threads` DISABLE KEYS */;
INSERT INTO `threads` VALUES ('081bfc61-0cb4-4a40-8270-7ad5af37f411','0c018773-3cc7-44d5-9ce9-777342e9f3a0','צריך לשנות את היחס לקנאביס כך שיהיה חוקי עם הרבה מס, כמו סיגריות','דיון ציבורי: האם נכון להפוך קנאביס לחוקי, עם מיסוי משמעותי לטובת בריאות הציבור?','2f44cff6-302d-4fed-bd17-d03b873d0759','open','2025-11-03 14:08:47'),('f2688e70-ff08-46dd-805b-bf585bb29936','0c018773-3cc7-44d5-9ce9-777342e9f3a0','Test Thread: Should we implement feature X?','This is a test thread for API development','2f44cff6-302d-4fed-bd17-d03b873d0759','open','2025-11-02 15:08:00');
/*!40000 ALTER TABLE `threads` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `topic_roles`
--

DROP TABLE IF EXISTS `topic_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `topic_roles` (
  `id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUID primary key',
  `topic_id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Reference to topics.id',
  `user_id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Reference to users.id',
  `role` enum('admin') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Role: admin (moderation centralized)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Role assignment timestamp',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_topic_roles_topic_user_role` (`topic_id`,`user_id`,`role`),
  KEY `fk_topic_roles_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Admin roles per topic (centralized moderation)';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `topic_roles`
--

LOCK TABLES `topic_roles` WRITE;
/*!40000 ALTER TABLE `topic_roles` DISABLE KEYS */;
/*!40000 ALTER TABLE `topic_roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `topics`
--

DROP TABLE IF EXISTS `topics`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `topics` (
  `id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUID primary key',
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Topic name',
  `description` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Topic description',
  `visibility` enum('public','private') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'public' COMMENT 'Topic visibility',
  `created_by` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'User who created the topic',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Topic creation timestamp',
  PRIMARY KEY (`id`),
  KEY `idx_topics_visibility` (`visibility`),
  KEY `idx_topics_created_by` (`created_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Discussion topics (e.g., national issues, local issues)';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `topics`
--

LOCK TABLES `topics` WRITE;
/*!40000 ALTER TABLE `topics` DISABLE KEYS */;
INSERT INTO `topics` VALUES ('0c018773-3cc7-44d5-9ce9-777342e9f3a0','Test Topic','A test topic for development','public','2f44cff6-302d-4fed-bd17-d03b873d0759','2025-11-02 15:08:00');
/*!40000 ALTER TABLE `topics` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_identities`
--

DROP TABLE IF EXISTS `user_identities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_identities` (
  `id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUID primary key',
  `user_id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Reference to users.id',
  `provider` enum('google','facebook','apple') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'OAuth provider name',
  `provider_user_id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'User ID from provider',
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Email from provider (may differ from users.email)',
  `display_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Display name from provider',
  `access_token_last4` varchar(4) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Last 4 chars of access token (for debugging)',
  `refresh_token_last4` varchar(4) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Last 4 chars of refresh token (for debugging)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Identity linking timestamp',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_identities_provider_user` (`provider`,`provider_user_id`),
  KEY `idx_user_identities_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Linked social authentication identities';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_identities`
--

LOCK TABLES `user_identities` WRITE;
/*!40000 ALTER TABLE `user_identities` DISABLE KEYS */;
INSERT INTO `user_identities` VALUES ('9114c2f5-bbe0-411d-a494-32061b5dabb5','374dd74c-f32a-4297-bc58-b30ac04ac2a6','google','109643218339820077617','tamirlevi123@gmail.com','Tamir Levy',NULL,NULL,'2025-11-04 14:41:20');
/*!40000 ALTER TABLE `user_identities` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUID primary key',
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Email address (unique if provided)',
  `phone` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Phone number (unique if provided)',
  `password_hash` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Bcrypt/Argon2 hash if using password auth',
  `display_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'User display name',
  `locale` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'he-IL' COMMENT 'Locale preference (default Hebrew)',
  `is_active` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Account active status',
  `role` enum('user','admin') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'user' COMMENT 'User role: user or admin',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Account creation timestamp',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_users_email` (`email`),
  UNIQUE KEY `uk_users_phone` (`phone`),
  KEY `idx_users_role` (`role`),
  KEY `idx_users_is_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Platform users';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES ('1a8a8328-aa53-465d-b1b2-ed5e2ee1456f','amir@dayparty.com',NULL,NULL,'Amir','he-IL',1,'user','2025-11-03 14:08:47'),('2f44cff6-302d-4fed-bd17-d03b873d0759','test@dayparty.com',NULL,NULL,'Test User','he-IL',1,'user','2025-11-02 15:08:00'),('374dd74c-f32a-4297-bc58-b30ac04ac2a6','tamirlevi123@gmail.com',NULL,NULL,'Tamir Levy','he-IL',1,'user','2025-11-04 14:41:20'),('43f8029f-123f-43f6-a4c6-cb14cf9cbf0f','yael@dayparty.com',NULL,NULL,'Yael','he-IL',1,'user','2025-11-03 14:08:47'),('69f76d75-a696-4249-ac82-6997b47e89df','noa@dayparty.com',NULL,NULL,'נועה','he-IL',1,'user','2025-11-03 14:08:47'),('f5ac0dc4-3145-4848-bf0c-72c919d25e4b','david@dayparty.com',NULL,NULL,'David','he-IL',1,'user','2025-11-03 14:08:47');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-11-08 12:07:27
