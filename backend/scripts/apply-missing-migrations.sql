-- Apply missing migrations to existing database
-- Run: mysql -u dayparty -p dayparty < scripts/apply-missing-migrations.sql
-- Password: DayParty2024!SecurePW

-- Migration 1: Add delta format support (safe - MODIFY is idempotent for enum values)
ALTER TABLE `nodes`
  MODIFY `text_format` ENUM('markdown', 'plain', 'html', 'delta') NOT NULL DEFAULT 'plain';

ALTER TABLE `node_versions`
  MODIFY `text_format` ENUM('markdown', 'plain', 'html', 'delta') NOT NULL;

-- Migration 2: Add metadata_json column (check first)
SET @col_exists = (
  SELECT COUNT(*) 
  FROM INFORMATION_SCHEMA.COLUMNS 
  WHERE TABLE_SCHEMA = 'dayparty' 
  AND TABLE_NAME = 'nodes' 
  AND COLUMN_NAME = 'metadata_json'
);

SET @sql = IF(@col_exists = 0,
  'ALTER TABLE `nodes` ADD COLUMN `metadata_json` JSON NULL;',
  'SELECT ''metadata_json column already exists'' AS message;'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Migration 3: Add external video support columns
-- Check if video_source exists
SET @col_exists = (
  SELECT COUNT(*) 
  FROM INFORMATION_SCHEMA.COLUMNS 
  WHERE TABLE_SCHEMA = 'dayparty' 
  AND TABLE_NAME = 'nodes' 
  AND COLUMN_NAME = 'video_source'
);

SET @sql = IF(@col_exists = 0,
  'ALTER TABLE `nodes`
    ADD COLUMN `video_source` ENUM(''upload'', ''external'') NOT NULL DEFAULT ''upload'' AFTER `video_thumbnail_url`,
    ADD COLUMN `video_provider` ENUM(''youtube'', ''vimeo'', ''other'') NULL AFTER `video_source`,
    ADD COLUMN `video_provider_id` VARCHAR(255) NULL AFTER `video_provider`,
    ADD COLUMN `video_embed_html` TEXT NULL AFTER `video_provider_id`,
    ADD COLUMN `video_metadata_json` JSON NULL AFTER `video_embed_html`,
    MODIFY `video_status` ENUM(''provided'', ''generated'', ''linked'', ''missing'') NOT NULL DEFAULT ''missing'';',
  'SELECT ''video_source column already exists in nodes'' AS message;'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Same for node_versions
SET @col_exists_v = (
  SELECT COUNT(*) 
  FROM INFORMATION_SCHEMA.COLUMNS 
  WHERE TABLE_SCHEMA = 'dayparty' 
  AND TABLE_NAME = 'node_versions' 
  AND COLUMN_NAME = 'video_source'
);

SET @sql_v = IF(@col_exists_v = 0,
  'ALTER TABLE `node_versions`
    ADD COLUMN `video_source` ENUM(''upload'', ''external'') NULL AFTER `video_thumbnail_url`,
    ADD COLUMN `video_provider` ENUM(''youtube'', ''vimeo'', ''other'') NULL AFTER `video_source`,
    ADD COLUMN `video_provider_id` VARCHAR(255) NULL AFTER `video_provider`,
    ADD COLUMN `video_embed_html` TEXT NULL AFTER `video_provider_id`,
    ADD COLUMN `video_metadata_json` JSON NULL AFTER `video_embed_html`,
    MODIFY `video_status` ENUM(''provided'', ''generated'', ''linked'', ''missing'') NOT NULL;',
  'SELECT ''video_source column already exists in node_versions'' AS message;'
);

PREPARE stmt_v FROM @sql_v;
EXECUTE stmt_v;
DEALLOCATE PREPARE stmt_v;
