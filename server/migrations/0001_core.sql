PRAGMA foreign_keys = ON;
CREATE TABLE users (
 uid TEXT PRIMARY KEY, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE admin_users (
 uid TEXT PRIMARY KEY REFERENCES users(uid), active INTEGER NOT NULL DEFAULT 1 CHECK(active IN(0,1))
);
-- Common revisioned storage for profile, goals, meals and weekly-plan slots.
CREATE TABLE records (
 uid TEXT NOT NULL REFERENCES users(uid), kind TEXT NOT NULL CHECK(kind IN('profile','goals','meal','plan')),
 id TEXT NOT NULL, data_json TEXT NOT NULL CHECK(json_valid(data_json)),
 version INTEGER NOT NULL CHECK(version>0), deleted_at TEXT, updated_at TEXT NOT NULL,
 last_op TEXT NOT NULL, PRIMARY KEY(uid,kind,id)
);
CREATE INDEX records_owner_kind ON records(uid,kind,updated_at,id);
CREATE TABLE changes (
 seq INTEGER PRIMARY KEY AUTOINCREMENT, uid TEXT NOT NULL, kind TEXT NOT NULL, id TEXT NOT NULL,
 version INTEGER NOT NULL, data_json TEXT NOT NULL, deleted_at TEXT, updated_at TEXT NOT NULL,
 op_id TEXT NOT NULL, UNIQUE(uid,op_id), FOREIGN KEY(uid,kind,id) REFERENCES records(uid,kind,id)
);
CREATE INDEX changes_owner_cursor ON changes(uid,seq);
CREATE TABLE sync_operations (
 uid TEXT NOT NULL REFERENCES users(uid), op_id TEXT NOT NULL, request_hash TEXT NOT NULL,
 result_json TEXT NOT NULL CHECK(json_valid(result_json)), created_at TEXT NOT NULL,
 PRIMARY KEY(uid,op_id)
);
CREATE TABLE assets (
 id TEXT PRIMARY KEY, uid TEXT NOT NULL REFERENCES users(uid), kind TEXT NOT NULL CHECK(kind IN('photo','pdf')),
 meal_id TEXT, public_id TEXT NOT NULL UNIQUE, format TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN('pending','ready','rejected','deleted')),
 version TEXT, bytes INTEGER, width INTEGER, height INTEGER, content_hash TEXT NOT NULL,
 expires_at INTEGER NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
 UNIQUE(uid,id), UNIQUE(uid,kind,content_hash,meal_id)
);
CREATE INDEX assets_owner ON assets(uid,kind,created_at,id);
CREATE TABLE device_tokens (
 installation_id TEXT PRIMARY KEY, uid TEXT NOT NULL REFERENCES users(uid),
 token TEXT NOT NULL UNIQUE, secret_hash TEXT NOT NULL, generation INTEGER NOT NULL, active INTEGER NOT NULL CHECK(active IN(0,1)),
 platform TEXT NOT NULL, app_version TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE INDEX devices_owner_active ON device_tokens(uid,active);
CREATE TABLE campaigns (
 id TEXT PRIMARY KEY, actor_uid TEXT NOT NULL REFERENCES users(uid), target_uid TEXT NOT NULL REFERENCES users(uid),
 request_key TEXT NOT NULL, request_hash TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, route TEXT NOT NULL,
 status TEXT NOT NULL, created_at TEXT NOT NULL, UNIQUE(actor_uid,request_key)
);
CREATE TABLE deliveries (
 id TEXT PRIMARY KEY, campaign_id TEXT NOT NULL REFERENCES campaigns(id), uid TEXT NOT NULL REFERENCES users(uid),
 installation_id TEXT NOT NULL, status TEXT NOT NULL, message_id TEXT, error_code TEXT,
 attempts INTEGER NOT NULL DEFAULT 0, next_attempt INTEGER, opened_at TEXT, updated_at TEXT NOT NULL,
 UNIQUE(campaign_id,installation_id)
);
CREATE INDEX deliveries_owner ON deliveries(uid,updated_at,id);
CREATE TABLE admin_audit_logs (
 id INTEGER PRIMARY KEY AUTOINCREMENT, actor_uid TEXT NOT NULL, action TEXT NOT NULL,
 target_id TEXT NOT NULL, request_id TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE crash_snapshots (
 id INTEGER PRIMARY KEY AUTOINCREMENT, app_id TEXT NOT NULL, source TEXT NOT NULL,
 payload_json TEXT NOT NULL CHECK(json_valid(payload_json)), fetched_at TEXT NOT NULL
);
CREATE TABLE maintenance_jobs (
 id TEXT PRIMARY KEY, asset_id TEXT NOT NULL REFERENCES assets(id), run_after INTEGER NOT NULL,
 attempts INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'pending'
);
CREATE TABLE rate_limits (
 bucket INTEGER NOT NULL, identity TEXT NOT NULL, count INTEGER NOT NULL,
 PRIMARY KEY(bucket,identity)
);
