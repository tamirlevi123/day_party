-- Adds 'delta' format option to TextFormat enum for Flutter Quill Delta JSON support

ALTER TABLE `nodes`
  MODIFY `text_format` ENUM('markdown', 'plain', 'html', 'delta') NOT NULL DEFAULT 'plain';

ALTER TABLE `node_versions`
  MODIFY `text_format` ENUM('markdown', 'plain', 'html', 'delta') NOT NULL;

