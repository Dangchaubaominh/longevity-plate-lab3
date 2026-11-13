ALTER TABLE records ADD COLUMN created_at TEXT;
UPDATE records SET created_at=updated_at WHERE created_at IS NULL;
