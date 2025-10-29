-- MySQL DDL for Day Party (מפלגת ד"י) Platform
-- Target: MySQL 8+
-- Character Set: utf8mb4 for full Unicode support (required for Hebrew/RTL)

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================================
-- Users and Authentication
-- ============================================================================

CREATE TABLE `users` (
  `id` CHAR(36) NOT NULL PRIMARY KEY COMMENT 'UUID primary key',
  `email` VARCHAR(255) NULL COMMENT 'Email address (unique if provided)',
  `phone` VARCHAR(50) NULL COMMENT 'Phone number (unique if provided)',
  `password_hash` VARCHAR(255) NULL COMMENT 'Bcrypt/Argon2 hash if using password auth',
  `display_name` VARCHAR(255) NOT NULL COMMENT 'User display name',
  `locale` VARCHAR(10) NOT NULL DEFAULT 'he-IL' COMMENT 'Locale preference (default Hebrew)',
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Account active status',
  `role` ENUM('user', 'admin') NOT NULL DEFAULT 'user' COMMENT 'User role: user or admin',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Account creation timestamp',
  UNIQUE KEY `uk_users_email` (`email`),
  UNIQUE KEY `uk_users_phone` (`phone`),
  INDEX `idx_users_role` (`role`),
  INDEX `idx_users_is_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Platform users';

-- Social identity providers (Google, Facebook, Apple)
CREATE TABLE `user_identities` (
  `id` CHAR(36) NOT NULL PRIMARY KEY COMMENT 'UUID primary key',
  `user_id` CHAR(36) NOT NULL COMMENT 'Reference to users.id',
  `provider` ENUM('google', 'facebook', 'apple') NOT NULL COMMENT 'OAuth provider name',
  `provider_user_id` VARCHAR(255) NOT NULL COMMENT 'User ID from provider',
  `email` VARCHAR(255) NULL COMMENT 'Email from provider (may differ from users.email)',
  `display_name` VARCHAR(255) NULL COMMENT 'Display name from provider',
  `access_token_last4` VARCHAR(4) NULL COMMENT 'Last 4 chars of access token (for debugging)',
  `refresh_token_last4` VARCHAR(4) NULL COMMENT 'Last 4 chars of refresh token (for debugging)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Identity linking timestamp',
  UNIQUE KEY `uk_user_identities_provider_user` (`provider`, `provider_user_id`),
  INDEX `idx_user_identities_user_id` (`user_id`),
  CONSTRAINT `fk_user_identities_user_id` FOREIGN KEY (`user_id`)
    REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Linked social authentication identities';

-- ============================================================================
-- Topics and Threads
-- ============================================================================

CREATE TABLE `topics` (
  `id` CHAR(36) NOT NULL PRIMARY KEY COMMENT 'UUID primary key',
  `name` VARCHAR(255) NOT NULL COMMENT 'Topic name',
  `description` TEXT NOT NULL COMMENT 'Topic description',
  `visibility` ENUM('public', 'private') NOT NULL DEFAULT 'public' COMMENT 'Topic visibility',
  `created_by` CHAR(36) NOT NULL COMMENT 'User who created the topic',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Topic creation timestamp',
  INDEX `idx_topics_visibility` (`visibility`),
  INDEX `idx_topics_created_by` (`created_by`),
  CONSTRAINT `fk_topics_created_by` FOREIGN KEY (`created_by`)
    REFERENCES `users` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Discussion topics (e.g., national issues, local issues)';

CREATE TABLE `topic_roles` (
  `id` CHAR(36) NOT NULL PRIMARY KEY COMMENT 'UUID primary key',
  `topic_id` CHAR(36) NOT NULL COMMENT 'Reference to topics.id',
  `user_id` CHAR(36) NOT NULL COMMENT 'Reference to users.id',
  `role` ENUM('admin') NOT NULL COMMENT 'Role: admin (moderation centralized)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Role assignment timestamp',
  UNIQUE KEY `uk_topic_roles_topic_user_role` (`topic_id`, `user_id`, `role`),
  CONSTRAINT `fk_topic_roles_topic_id` FOREIGN KEY (`topic_id`)
    REFERENCES `topics` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_topic_roles_user_id` FOREIGN KEY (`user_id`)
    REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Admin roles per topic (centralized moderation)';

CREATE TABLE `threads` (
  `id` CHAR(36) NOT NULL PRIMARY KEY COMMENT 'UUID primary key',
  `topic_id` CHAR(36) NOT NULL COMMENT 'Reference to topics.id',
  `title` VARCHAR(500) NOT NULL COMMENT 'Thread title',
  `description` TEXT NULL COMMENT 'Thread description (optional)',
  `created_by` CHAR(36) NOT NULL COMMENT 'User who created the thread',
  `status` ENUM('open', 'closed') NOT NULL DEFAULT 'open' COMMENT 'Thread status',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Thread creation timestamp',
  INDEX `idx_threads_topic_id` (`topic_id`),
  INDEX `idx_threads_created_by` (`created_by`),
  CONSTRAINT `fk_threads_topic_id` FOREIGN KEY (`topic_id`)
    REFERENCES `topics` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_threads_created_by` FOREIGN KEY (`created_by`)
    REFERENCES `users` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Discussion threads within topics';

-- ============================================================================
-- Nodes (Tree Structure for Posts/Comments with Voting)
-- ============================================================================

CREATE TABLE `nodes` (
  `id` CHAR(36) NOT NULL PRIMARY KEY COMMENT 'UUID primary key',
  `thread_id` CHAR(36) NOT NULL COMMENT 'Reference to threads.id',
  `parent_node_id` CHAR(36) NULL COMMENT 'Parent node for tree structure (NULL = root)',
  `parent_relation` ENUM('pro', 'against', 'neutral') NULL COMMENT 'Relation to parent node (PRO/AGAINST/NEUTRAL). NULL for root nodes.',
  `title` VARCHAR(500) NOT NULL COMMENT 'Node title',
  
  -- Content modalities
  `text_content` TEXT NULL COMMENT 'Rich text content',
  `text_format` ENUM('markdown', 'plain') NOT NULL DEFAULT 'plain' COMMENT 'Text format',
  `video_url` VARCHAR(2048) NULL COMMENT 'Video storage URL/location',
  `video_duration_sec` INT NULL COMMENT 'Video duration in seconds',
  `video_thumbnail_url` VARCHAR(2048) NULL COMMENT 'Video thumbnail URL',
  
  -- Metadata
  `text_language` VARCHAR(10) NULL COMMENT 'Detected language (e.g., he, en)',
  `text_confidence` DECIMAL(5,4) NULL COMMENT 'Confidence score if generated/transcribed (0-1)',
  `text_status` ENUM('provided', 'generated', 'missing') NOT NULL DEFAULT 'missing' COMMENT 'Text source status',
  `video_status` ENUM('provided', 'generated', 'missing') NOT NULL DEFAULT 'missing' COMMENT 'Video source status',
  
  -- Moderation
  `moderation_state` ENUM('visible', 'limited', 'hidden', 'removed') NOT NULL DEFAULT 'visible' COMMENT 'Moderation visibility state',
  `is_anonymous` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Whether node is anonymous',
  `author_id` CHAR(36) NULL COMMENT 'Author user ID (nullable for anonymous nodes)',
  `is_deleted` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Soft delete flag',
  
  -- Voting configuration (root nodes only for deadlines)
  `voting_enabled` BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Whether voting is enabled on this node',
  `voting_closes_at` DATETIME NULL COMMENT 'Voting deadline (root nodes only)',
  `voting_required_quorum` INT NULL COMMENT 'Minimum votes required (informational, not enforced)',
  `voting_default_public` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Default visibility for votes',
  `voting_eligibility_min_account_age_days` INT NULL COMMENT 'Minimum account age to vote (if set)',
  
  -- Denormalized tallies (update via triggers or application layer)
  `like_count` INT NOT NULL DEFAULT 0 COMMENT 'Cached like vote count',
  `dislike_count` INT NOT NULL DEFAULT 0 COMMENT 'Cached dislike vote count',
  `abstain_count` INT NOT NULL DEFAULT 0 COMMENT 'Cached abstain vote count',
  
  -- Timestamps
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Node creation timestamp',
  `edited_at` DATETIME NULL COMMENT 'Last edit timestamp',
  
  INDEX `idx_nodes_thread_id` (`thread_id`),
  INDEX `idx_nodes_parent_node_id` (`parent_node_id`),
  INDEX `idx_nodes_author_id` (`author_id`),
  INDEX `idx_nodes_moderation_state` (`moderation_state`),
  INDEX `idx_nodes_is_deleted` (`is_deleted`),
  INDEX `idx_nodes_voting_closes_at` (`voting_closes_at`),
  CONSTRAINT `fk_nodes_thread_id` FOREIGN KEY (`thread_id`)
    REFERENCES `threads` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_nodes_parent_node_id` FOREIGN KEY (`parent_node_id`)
    REFERENCES `nodes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_nodes_author_id` FOREIGN KEY (`author_id`)
    REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Nodes form a tree structure for discussions; each node can have text/video and voting';

CREATE TABLE `node_versions` (
  `id` CHAR(36) NOT NULL PRIMARY KEY COMMENT 'UUID primary key',
  `node_id` CHAR(36) NOT NULL COMMENT 'Reference to nodes.id',
  `version_number` INT NOT NULL COMMENT 'Version number (1-based incremental)',
  `title` VARCHAR(500) NOT NULL COMMENT 'Title at this version',
  `text_content` TEXT NULL COMMENT 'Text content at this version',
  `text_format` ENUM('markdown', 'plain') NOT NULL COMMENT 'Text format',
  `video_url` VARCHAR(2048) NULL COMMENT 'Video URL at this version',
  `video_duration_sec` INT NULL COMMENT 'Video duration',
  `video_thumbnail_url` VARCHAR(2048) NULL COMMENT 'Video thumbnail URL',
  `text_language` VARCHAR(10) NULL COMMENT 'Text language',
  `text_confidence` DECIMAL(5,4) NULL COMMENT 'Confidence score',
  `text_status` ENUM('provided', 'generated', 'missing') NOT NULL COMMENT 'Text status',
  `video_status` ENUM('provided', 'generated', 'missing') NOT NULL COMMENT 'Video status',
  `moderation_state` ENUM('visible', 'limited', 'hidden', 'removed') NOT NULL COMMENT 'Moderation state',
  `edited_by` CHAR(36) NULL COMMENT 'User who made this edit (uploader or admin)',
  `edited_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Edit timestamp',
  `change_summary` TEXT NULL COMMENT 'Summary of changes in this version',
  UNIQUE KEY `uk_node_versions_node_version` (`node_id`, `version_number`),
  INDEX `idx_node_versions_node_id` (`node_id`, `version_number` DESC),
  CONSTRAINT `fk_node_versions_node_id` FOREIGN KEY (`node_id`)
    REFERENCES `nodes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_node_versions_edited_by` FOREIGN KEY (`edited_by`)
    REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Immutable version history for nodes (for auditability and change notifications)';

CREATE TABLE `node_votes` (
  `id` CHAR(36) NOT NULL PRIMARY KEY COMMENT 'UUID primary key',
  `node_id` CHAR(36) NOT NULL COMMENT 'Reference to nodes.id',
  `user_id` CHAR(36) NOT NULL COMMENT 'Voter user ID',
  `type` ENUM('like', 'dislike', 'abstain') NOT NULL COMMENT 'Vote type',
  `is_public` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Whether vote visibility is public',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Vote creation timestamp',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
  UNIQUE KEY `uk_node_votes_node_user` (`node_id`, `user_id`) COMMENT 'One vote per user per node',
  INDEX `idx_node_votes_node_id` (`node_id`),
  INDEX `idx_node_votes_user_id` (`user_id`),
  INDEX `idx_node_votes_node_public` (`node_id`, `is_public`) COMMENT 'For public voter lists',
  CONSTRAINT `fk_node_votes_node_id` FOREIGN KEY (`node_id`)
    REFERENCES `nodes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_node_votes_user_id` FOREIGN KEY (`user_id`)
    REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='User votes on nodes (like/dislike/abstain) with per-vote visibility control';

-- ============================================================================
-- Modality Generation Jobs
-- ============================================================================

CREATE TABLE `modality_generation_jobs` (
  `id` CHAR(36) NOT NULL PRIMARY KEY COMMENT 'UUID primary key',
  `node_id` CHAR(36) NOT NULL COMMENT 'Reference to nodes.id',
  `target_modality` ENUM('text', 'video') NOT NULL COMMENT 'Modality to generate',
  `source` ENUM('ai', 'human') NOT NULL COMMENT 'Generation source (AI or human)',
  `status` ENUM('queued', 'in_progress', 'succeeded', 'failed') NOT NULL COMMENT 'Job status',
  `requested_by` CHAR(36) NULL COMMENT 'User who requested generation',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Job creation timestamp',
  `completed_at` DATETIME NULL COMMENT 'Job completion timestamp',
  `notes` TEXT NULL COMMENT 'Notes or error messages',
  INDEX `idx_modality_jobs_node_modality` (`node_id`, `target_modality`),
  INDEX `idx_modality_jobs_status` (`status`),
  CONSTRAINT `fk_modality_jobs_node_id` FOREIGN KEY (`node_id`)
    REFERENCES `nodes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_modality_jobs_requested_by` FOREIGN KEY (`requested_by`)
    REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Background jobs for generating missing text/video modalities';

-- ============================================================================
-- Reports and Moderation
-- ============================================================================

CREATE TABLE `reports` (
  `id` CHAR(36) NOT NULL PRIMARY KEY COMMENT 'UUID primary key',
  `target_type` ENUM('thread', 'node') NOT NULL COMMENT 'Type of reported content',
  `target_id` CHAR(36) NOT NULL COMMENT 'ID of reported thread or node (polymorphic)',
  `reporter_id` CHAR(36) NOT NULL COMMENT 'User who created the report',
  `reason` TEXT NOT NULL COMMENT 'Report reason/description',
  `status` ENUM('open', 'reviewing', 'resolved', 'rejected') NOT NULL DEFAULT 'open' COMMENT 'Report status',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Report creation timestamp',
  `resolved_by` CHAR(36) NULL COMMENT 'Admin who resolved the report',
  `resolved_at` DATETIME NULL COMMENT 'Resolution timestamp',
  INDEX `idx_reports_target` (`target_type`, `target_id`),
  INDEX `idx_reports_status` (`status`),
  INDEX `idx_reports_reporter_id` (`reporter_id`),
  CONSTRAINT `fk_reports_reporter_id` FOREIGN KEY (`reporter_id`)
    REFERENCES `users` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_reports_resolved_by` FOREIGN KEY (`resolved_by`)
    REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Content reports for moderation (polymorphic: threads or nodes)';

-- ============================================================================
-- Notifications
-- ============================================================================

CREATE TABLE `notifications` (
  `id` CHAR(36) NOT NULL PRIMARY KEY COMMENT 'UUID primary key',
  `user_id` CHAR(36) NOT NULL COMMENT 'Recipient user ID',
  `type` VARCHAR(100) NOT NULL COMMENT 'Notification type (e.g., node_updated, node_reply)',
  `payload_json` JSON NOT NULL COMMENT 'Notification payload as JSON',
  `is_read` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Read status',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Notification creation timestamp',
  INDEX `idx_notifications_user_read` (`user_id`, `is_read`),
  INDEX `idx_notifications_created_at` (`created_at`),
  CONSTRAINT `fk_notifications_user_id` FOREIGN KEY (`user_id`)
    REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='User notifications (node updates, replies, moderation, etc.)';

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- Notes
-- ============================================================================
-- Application-level constraints:
-- - At least one of (text_content, video_url) must be non-null on node creation
-- - voting_closes_at should only be set on root nodes (parent_node_id IS NULL)
-- - Only admins can set/change voting_closes_at
-- - Vote changes allowed until voting_closes_at
-- - Quorum is informational only (not enforced)
-- - Voting eligibility checks account age if voting_eligibility_min_account_age_days is set

