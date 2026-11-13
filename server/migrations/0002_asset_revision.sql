ALTER TABLE assets ADD COLUMN meal_version INTEGER;
CREATE UNIQUE INDEX one_ready_photo_per_meal ON assets(uid,meal_id) WHERE kind='photo' AND status='ready';
