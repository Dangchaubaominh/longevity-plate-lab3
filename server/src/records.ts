import { ApiError, digest, nowIso, type Row } from "./types";
import { operation, parseData, type Operation } from "./schemas";

export async function ensureUser(db: D1Database, uid: string) {
  const now = nowIso();
  await db
    .prepare(
      "INSERT INTO users(uid,created_at,updated_at) VALUES(?,?,?) ON CONFLICT(uid) DO NOTHING",
    )
    .bind(uid, now, now)
    .run();
}
export function record(row: Row) {
  return {
    id: row.id,
    kind: row.kind,
    data: JSON.parse(String(row.data_json)) as unknown,
    version: row.version,
    deletedAt: row.deleted_at,
    updatedAt: row.updated_at,
    createdAt: row.created_at,
    seq: row.seq,
  };
}
export async function applyOperation(
  db: D1Database,
  uid: string,
  input: Operation,
) {
  const op = operation.parse(input);
  if ((op.kind === "profile" || op.kind === "goals") && op.id !== "self")
    throw new ApiError(400, "invalid_record_id");
  const data = parseData(op);
  const json = JSON.stringify(data);
  const hash = await digest(JSON.stringify({ ...op, data }));
  const previous = await db
    .prepare(
      "SELECT request_hash,result_json FROM sync_operations WHERE uid=? AND op_id=?",
    )
    .bind(uid, op.opId)
    .first<Row>();
  if (previous) {
    if (previous.request_hash !== hash)
      throw new ApiError(409, "idempotency_conflict");
    return JSON.parse(String(previous.result_json)) as Row;
  }
  const current = await db
    .prepare("SELECT version FROM records WHERE uid=? AND kind=? AND id=?")
    .bind(uid, op.kind, op.id)
    .first<Row>();
  if ((!current && op.baseVersion !== 0) || (!current && op.deleted))
    throw new ApiError(404, "not_found");
  const now = nowIso();
  const deleted = op.deleted ? now : null;
  await db.batch([
    db
      .prepare(
        `INSERT INTO records(uid,kind,id,data_json,version,deleted_at,updated_at,last_op,created_at) VALUES(?,?,?,?,1,?,?,?,?)
   ON CONFLICT(uid,kind,id) DO UPDATE SET data_json=excluded.data_json,version=records.version+1,deleted_at=excluded.deleted_at,updated_at=excluded.updated_at,last_op=excluded.last_op WHERE records.version=?`,
      )
      .bind(
        uid,
        op.kind,
        op.id,
        json,
        deleted,
        now,
        op.opId,
        now,
        op.baseVersion,
      ),
    db
      .prepare(
        `INSERT INTO changes(uid,kind,id,version,data_json,deleted_at,updated_at,op_id)
   SELECT uid,kind,id,version,data_json,deleted_at,updated_at,last_op FROM records WHERE uid=? AND kind=? AND id=? AND last_op=? ON CONFLICT(uid,op_id) DO NOTHING`,
      )
      .bind(uid, op.kind, op.id, op.opId),
    db
      .prepare(
        `INSERT INTO sync_operations(uid,op_id,request_hash,result_json,created_at)
   SELECT uid,?,?,json_object('id',id,'kind',kind,'version',version,'data',json(data_json),'deletedAt',deleted_at,'updatedAt',updated_at,'createdAt',created_at),? FROM records WHERE uid=? AND kind=? AND id=? AND last_op=? ON CONFLICT(uid,op_id) DO NOTHING`,
      )
      .bind(op.opId, hash, now, uid, op.kind, op.id, op.opId),
  ]);
  const saved = await db
    .prepare(
      "SELECT request_hash,result_json FROM sync_operations WHERE uid=? AND op_id=?",
    )
    .bind(uid, op.opId)
    .first<Row>();
  if (!saved) throw new ApiError(409, "version_conflict");
  if (saved.request_hash !== hash)
    throw new ApiError(409, "idempotency_conflict");
  return JSON.parse(String(saved.result_json)) as Row;
}
export async function audit(
  db: D1Database,
  actor: string,
  action: string,
  target: string,
  requestId: string,
) {
  await db
    .prepare(
      "INSERT INTO admin_audit_logs(actor_uid,action,target_id,request_id,created_at) VALUES(?,?,?,?,?)",
    )
    .bind(actor, action, target, requestId, nowIso())
    .run();
}
