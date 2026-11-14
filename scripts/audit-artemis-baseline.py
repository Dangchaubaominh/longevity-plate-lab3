"""Export the historical thirty adjudicated runs without rewriting their labels.

Only hashes, action metadata and allowlisted app labels are public. Raw goals
and provider UI remain in the ignored DataEngine database.
"""
import hashlib
import json
import sqlite3
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'artifacts/artemis-runs'
OUT = ROOT / 'docs/build-evidence/artemis-remediation'
OUT.mkdir(parents=True, exist_ok=True)
baseline_file = ROOT / 'docs/build-evidence/artemis-summary.json'
baseline = json.loads(baseline_file.read_text(encoding='utf8'))
runs = json.loads((RAW / 'suite-results.json').read_text(encoding='utf8'))
db = sqlite3.connect(f'file:{(RAW / "traces/data_engine.db").as_posix()}?mode=ro', uri=True)

# Primary categories are mutually exclusive per failed run. Contributors are
# explained separately; two gesture-ambiguous specifications differ from runs
# where the agent never reached the form at all.
CAUSES = {
 'AR03-R2': ('C', [1, 5, 6], 'Lặp Home → Nhật ký; không mở form mới, không nhập và không lưu record đúng nhãn.', 'Chuẩn bị form mới; kiểm tra màn trước nhập; backend oracle theo nhãn riêng mỗi campaign.'),
 'AR03-R3': ('C', [1, 2, 4, 5], 'Nhấn tọa độ/target rỗng từ Nhật ký; không có action nhập mô tả hoặc lưu; record đúng nhãn không xuất hiện trong snapshot cloud.', 'Kiểm tra target hợp lệ và màn form; read-back trường và kiểm tra đúng một record lunch.'),
 'AR04-R1': ('B', [4, 5, 8, 9], 'Goal viết SCROLL DOWN theo chiều nội dung, tool down kéo ngón tay xuống. Sau một swipe up ngắn, agent bấm Save lại và đưa focus về lỗi đầu.', 'Mô tả rõ vuốt ngón tay lên, chờ màn ổn định; giữ hai lỗi và quan sát từng trường, không resubmit để cuộn.'),
 'AR04-R2': ('C', [1, 2, 3], 'Trace chỉ có ba click trước kết luận, dừng ở Nhật ký thay vì form validation.', 'Preflight form route; không cho kết luận nếu thiếu các mốc Save và lỗi bắt buộc.'),
 'AR04-R3': ('B', [4, 5, 10, 13, 14], 'Lặp tool swipe down; hai swipe up chỉ quay về vùng loại bữa/ảnh, chưa đến lỗi tên món.', 'Hướng cuộn theo tọa độ ngón tay; label/identifier trường; summary lỗi cho form dài.'),
 'AR05-R3': ('C', [1, 2, 3, 4, 6], 'Rời Nhật ký tới launcher rồi mở lại app; không có input mô tả hoặc hộp bỏ bản nháp.', 'Phân biệt tab Hôm nay với Android Home; chặn phím Home trong campaign và đòi dialog + record absence.'),
 'AR07-R1': ('C', [11, 12, 14, 18], 'Mở Xem chi tiết của món đang có, rồi quay lại; không chọn công thức khác và không mở dialog thay thế.', 'Đi qua Chọn món ở slot trống, chọn Bánh mì và trứng, đặt lại slot test rồi mới submit và Hủy.'),
 'AR07-R2': ('C', [2, 3, 4, 5], 'Chỉ mở món hiện tại rồi chuyển tab; không có submit hay thao tác Hủy dialog.', 'Fixture đúng slot và recipe candidate khác recipe gốc; oracle so sánh server revision trước/sau.'),
 'AR07-R3': ('C', [4, 7, 10, 11], 'Tìm kiếm trong thư viện bài viết thay vì chọn công thức; tiếp tục mở recipe hiện tại và Back.', 'Phân biệt bài viết và công thức; mở bộ chọn món; xác nhận tên candidate trước thao tác.'),
 'AR08-R2': ('C', [2, 4, 5], 'Ảnh cho thấy ô app vẫn trống; chuỗi chỉ ở gợi ý clipboard của bàn phím sau input_text.', 'Read-back đúng EditText thuộc package app; driver nhập không được xác nhận từ clipboard.'),
 'AR08-R3': ('C', [2, 8, 9], 'input_text đặt chuỗi ở clipboard, app không hiện truy vấn hoặc empty state.', 'ASCII fixture qua input native có kiểm tra focus và giá trị; lỗi read-back phải trả lỗi thao tác.'),
 'AR13-R1': ('C', [6, 7, 28, 35, 37], 'Picker có mở nhưng preview/asset là ảnh người dùng đã chọn trước đó, không phải bowl fixture yêu cầu. Asset228597bytes khác fixture8589bytes.', 'Fixture trong album riêng có tên duy nhất và manifest hash; đối chiếu ảnh input/asset, không chọn ảnh khác để hoàn thành ca.'),
 'AR13-R2': ('C', [1, 4, 5], 'Chỉ xem ảnh của record có sẵn rồi đóng viewer; không có picker hoặc record mới đúng nhãn.', 'Form sạch theo campaign; yêu cầu picker transition và ready asset gắn đúng record mới.'),
 'AR13-R3': ('C', [6, 19, 20], 'Sau picker, agent gọi manage_app launch package khác; người vận hành dừng phiên.', 'Scope guard trước dispatch và screenshot; manage_app chỉ launch package app; từ chối launcher và app khác.'),
}

def safe_action(raw):
 a = json.loads(raw or '{}'); args = a.get('args') or {}
 target = str(a.get('target_text', ''))
 if '@' in target or len(target) > 140:
  target = '[private label omitted]'
 result = {'tool': a.get('action'), 'target': target}
 for key in ['direction', 'key', 'clear_exist']:
  if key in args:
   result[key] = args[key]
 if 'text' in args:
  result['text'] = args['text'] if str(args['text']).startswith(('ARTEMIS_', 'dia an')) else '[input omitted]'
 if a.get('action') == 'manage_app':
  result['target'] = '[app-management action; see scope finding]'
 return result

all_rows = []
for case in baseline['cases']:
 for official in case['runs']:
  name = f"{case['caseId']}-R{official['run']}"
  candidates = [x for x in runs if x['name'] == name]
  selected = next(x for x in reversed(candidates) if x.get('session') == official['session'])
  steps = db.execute('SELECT step_number,timestamp,pre_image_name,post_image_name,action_taken FROM steps WHERE session_id=? ORDER BY step_number', (official['session'],)).fetchall()
  is_fail = official['result'] == 'FAIL'
  kind, decisive, reason, remedy = CAUSES[name] if is_fail else (None, [], 'Baseline được giữ nguyên; không tái diễn giải thành kết quả chạy mới.', 'Giữ expected và kiểm tra lại trong campaign mới.')
  evidence = []
  for number, timestamp, pre, post, raw in steps:
   # Never export actions/UI inside the unrelated app.
   if name == 'AR13-R3' and number > 20:
    break
   evidence.append({'step': number, 'timestamp': timestamp, **safe_action(raw),
                    'preImage': pre, 'postImage': post, 'decisive': number in decisive})
  all_rows.append({'testId': case['caseId'], 'name': name, 'run': official['run'],
                   'flow': case['flow'], 'session': official['session'],
                   'baselineResult': official['result'], 'selectedAttempt': selected.get('attempt', 1),
                   'rawAttemptsForName': len(candidates), 'agentReportedResult': selected.get('reportedSuccess'),
                   'start': selected.get('start'), 'end': selected.get('end'),
                   'interrupted': bool(selected.get('interrupted')),
                   'category': kind, 'rootCause': reason, 'remediation': remedy,
                   'expected': case['flow'] + '; detailed preconditions and expected values in docs/ARTEMIS_CASES.md',
                   'evidence': evidence})

counts = {k: sum(r['category'] == k for r in all_rows) for k in 'ABCDE'}
assert len(all_rows) == 30 and sum(r['baselineResult'] == 'FAIL' for r in all_rows) == 14
assert sum(counts.values()) == 14
report = {'baselineSha256': hashlib.sha256(baseline_file.read_bytes()).hexdigest(),
          'baseline': {'pass': 16, 'fail': 14, 'ratePercent': 53.33, 'officialRuns': 30, 'rawAttempts': len(runs)},
          'selectionRule': 'One historical adjudicated session per case/run, matching artemis-summary.json; all36rawattempts retained.',
          'primaryCategoryCounts': counts, 'runs': all_rows}
target = OUT / 'baseline-analysis.json'
target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
lines = ['# Phân tích nguyên nhân ARTEMIS baseline', '',
 'Baseline lịch sử giữ nguyên16/30PASS,14/30FAIL,53,33%;30lượt chính thức được chọn theo session trong artemis-summary.json. Có36rawattempts gồm retry. Đây không phải số liệu chạy lại.', '',
 '## Phân loại', '',
 '| Nhóm | Số lượt FAIL chính |', '|---|---:|',
 *[f'| {k} | {counts[k]} |' for k in 'ABCDE'], '',
 'A ứng dụng; B thiết kế ca; C công cụ/tác nhân; D môi trường; E không đủ bằng chứng. Mỗi lượt có một nguyên nhân chính. Yếu tố góp phần được ghi riêng; số này không phải số lỗi code độc lập.', '',
 'Nhóm ảnh hưởng lớn nhất là C với12/14lượt. Hai lượt B có hướng cuộn mơ hồ; các lượt còn lại có chuỗi thao tác đi sai màn, nhập clipboard không vào trường, chọn sai ảnh hoặc vượt phạm vi. Không tìm thấy bằng chứng từ14lượt để kết luận một lỗi P0 về mất dữ liệu, owner hay idempotency. Sự thiếu ổn định của hierarchy ở form dài là yếu tố hỗ trợ cần kiểm tra khả năng truy cập, không được coi là lỗi nghiệp vụ đã tái hiện trên máy thật.', '',
 '## Mười bốn lượt không đạt', '',
 '| Test | Run | Gốc | Nhóm và nguyên nhân | Bằng chứng | Cách xử lý | Trạng thái |', '|---|---:|---|---|---|---|---|']
for r in all_rows:
 if r['category']:
  refs = ', '.join(f"s{x['step']}:{(x['postImage'] or x['preImage'] or '')[:12]}" for x in r['evidence'] if x['decisive'])
  lines.append(f"| {r['testId']} | {r['run']} | FAIL | {r['category']}: {r['rootCause']} | session {r['session']}; {refs} | {r['remediation']} | Đã phân tích; kiểm chứng bản sửa ghi riêng |")
lines += ['', '## Tất cả ba mươi lượt baseline', '', '| Test | Run | Gốc | Session | Steps |', '|---|---:|---|---|---:|']
for r in all_rows:
 lines.append(f"| {r['testId']} | {r['run']} | {r['baselineResult']} | {r['session']} | {len(r['evidence'])} |")
lines += ['', '## Truy vết chi tiết', '',
 '`docs/build-evidence/artemis-remediation/baseline-analysis.json` chứa action timeline, timestamps, hashes ảnh và các mốc quyết định cho cả30lượt. Raw log theo tên trong artifacts/artemis-runs; ảnh ở traces/images/<hash>.jpg; các bước gốc nằm trong traces/data_engine.db. Phần ứng dụng ngoài phạm vi được loại khỏi bản xuất công khai. Không đọc hoặc đưa nội dung riêng tư của ứng dụng đó vào báo cáo.', '',
 'Kết quả baseline và schema phân loại được giữ độc lập với campaign chạy lại. Trạng thái bản sửa, lệnh test mới, build/commit và30lượt mới chỉ được cập nhật sau thực thi.']
(ROOT/'docs/ARTEMIS_ROOT_CAUSE_ANALYSIS.md').write_text('\n'.join(lines)+'\n', encoding='utf8')
print(json.dumps({'official': len(all_rows), 'attempts': len(runs), 'primaryCategories': counts}))
