-- Update text_format enum to include 'html'
ALTER TABLE nodes MODIFY COLUMN text_format ENUM('markdown', 'plain', 'html') NOT NULL DEFAULT 'plain';

