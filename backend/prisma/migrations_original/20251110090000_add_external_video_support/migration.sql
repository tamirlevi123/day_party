-- Day Party Migration: Add external video link support
-- Generated manually on 2025-11-10

ALTER TABLE `nodes`
  ADD COLUMN `video_source` ENUM('upload', 'external') NOT NULL DEFAULT 'upload' AFTER `video_thumbnail_url`,
  ADD COLUMN `video_provider` ENUM('youtube', 'vimeo', 'other') NULL AFTER `video_source`,
  ADD COLUMN `video_provider_id` VARCHAR(255) NULL AFTER `video_provider`,
  ADD COLUMN `video_embed_html` TEXT NULL AFTER `video_provider_id`,
  ADD COLUMN `video_metadata_json` JSON NULL AFTER `video_embed_html`;

ALTER TABLE `nodes`
  MODIFY `video_status` ENUM('provided', 'generated', 'linked', 'missing') NOT NULL DEFAULT 'missing';

ALTER TABLE `node_versions`
  ADD COLUMN `video_source` ENUM('upload', 'external') NULL AFTER `video_thumbnail_url`,
  ADD COLUMN `video_provider` ENUM('youtube', 'vimeo', 'other') NULL AFTER `video_source`,
  ADD COLUMN `video_provider_id` VARCHAR(255) NULL AFTER `video_provider`,
  ADD COLUMN `video_embed_html` TEXT NULL AFTER `video_provider_id`,
  ADD COLUMN `video_metadata_json` JSON NULL AFTER `video_embed_html`;

ALTER TABLE `node_versions`
  MODIFY `video_status` ENUM('provided', 'generated', 'linked', 'missing') NOT NULL;

