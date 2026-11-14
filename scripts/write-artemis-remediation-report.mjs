import {readFileSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..'),campaign=process.argv[2];
if(!/^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/.test(campaign||''))throw new Error('Campaign required');
const summaryPath=`docs/build-evidence/artemis-remediation/${campaign}-summary.json`;
const s=JSON.parse(readFileSync(resolve(root,summaryPath)));
const raw=resolve(root,'artifacts/artemis-campaigns',campaign);
const attempts=JSON.parse(readFileSync(resolve(raw,'suite-results.json')));
const manifest=JSON.parse(readFileSync(resolve(raw,'build-manifest.json')));
const newRows=s.runs.filter(r=>r.baselineResult==='FAIL');
const complete=newRows.every(r=>r.rerunStatus==='PASS');
const assistedNote='Ba lượt AR13 đều có người dùng tự chọn ảnh fixture. Tác nhân báo PASS cả ba; R3 có ảnh popup, R1/R2 còn thiếu ảnh popup trong trace và giữ PENDING_REVIEW. Người dùng yêu cầu dừng đối chiếu, không chạy thêm. Kết quả báo về tổng hợp 30/30; bằng chứng đầy đủ xác nhận 28/30.';
const stamp=new Intl.DateTimeFormat('vi-VN',{timeZone:'Asia/Bangkok',dateStyle:'short',timeStyle:'medium'}).format(new Date());
const table=['| Lượt | Baseline | Chạy lại | Session được chọn | Attempt |','|---|---|---|---|---:|',
  ...newRows.map(r=>`| ${r.name} | FAIL | ${r.rerunStatus} | ${r.session||'—'} | ${r.attempt||'—'} |`)].join('\n');
const text=`# ARTEMIS remediation — ${complete?'kết quả hoàn tất':'tiến độ thực tế'}

Cập nhật ${stamp} (Asia/Bangkok). Campaign \`${campaign}\`.

## Kết quả và cách tính

${assistedNote}

- Baseline lịch sử: **16/30 PASS, 14 FAIL, 53,33%**, 36 raw attempts. Giữ nguyên file baseline và SHA-256 \`${s.baselineSha256}\`.
- Chạy lại đúng 14 cặp baseline FAIL: **${s.rerun.passed}/14 PASS được xác minh**. Đã có ${s.rerun.distinctRuns} cặp được thử, ${attempts.length} raw attempts; retries/lỗi cấu hình/lỗi provider vẫn giữ riêng.
- Tổng hợp: **${s.combined.passed}/30 PASS (${s.combined.passRatePercent}%)**, còn ${s.combined.unresolved} lượt chưa được xác nhận đạt. Số này kết hợp **16 PASS lịch sử** với PASS chạy lại, không phải 30 lượt chạy mới trên cùng APK/model.
- Những PASS đã xác minh được giữ nguyên theo yêu cầu, không chạy lại hoặc đối chiếu lại.

${table}

## Nguyên nhân và cách sửa

RCA baseline có sẵn trong \`ARTEMIS_ROOT_CAUSE_ANALYSIS.md\` và \`baseline-analysis.json\`: B=2 lượt, C=12 lượt, A/D/E=0 lượt có bằng chứng chính. Không diễn giải 14 lượt FAIL thành 14 lỗi ứng dụng độc lập. Chưa xác nhận hoặc sửa lỗi nghiệp vụ ứng dụng trong phiên remediation này.

1. Cuộn/target sai: ARTEMIS nhấn phần card bị cắt dưới CTA. Làm rõ vuốt ngón tay lên toàn màn hình, chỉ nhập khi ô thực sự hiện và nhận focus. AR04 giữ yêu cầu đủ cả hai validation. AR03/AR05 mở đúng journal rồi form, phân biệt chính xác nhãn từng run.
2. Nhập liệu: clipboard SUCCESS không chứng minh trường app nhận chữ; native key injection còn bị Telex biến ARTEMIS thành chữ có dấu. Driver opt-in dùng UIAutomator ACTION_SET_TEXT trên đúng EditText đang focus trong package app, đọc lại giá trị chính xác. Actuator chuyển quyền thay/append cho driver để tránh xóa thiếu rồi nối chuỗi. Không đổi bàn phím người dùng, validation, login hoặc bảo mật ứng dụng.
3. Phạm vi và lịch sử: chặn launch/stop app khác, phím Home/app switch/power và capture ngoài package cho campaign này; Scope guard vẫn chặn capture picker AR13; người dùng hỗ trợ chọn ảnh, chưa sửa xong giới hạn này. Runner vẫn chạy từng lượt có giám sát. Mỗi campaign có thư mục/nhãn riêng, giữ mọi retry, không dùng agent SUCCESS làm kết quả cuối.

Đã xác minh giải quyết ${s.rerun.passed} **lượt FAIL baseline** thuộc test/tool; đây không phải số lỗi code độc lập. Hai ca AR13-R1/R2 còn thiếu ảnh popup; không thực hiện thêm theo yêu cầu người dùng. Các lần đánh giá AR08 ban đầu nhầm PASS vì chỉ thấy empty state đã được sửa thành FAIL khi phát hiện truy vấn sai từng ký tự; lịch sử sửa đánh giá vẫn lưu trong adjudication.json.

## Kiểm thử đã thực sự chạy

- Flutter analyzer: no issues. Flutter regression: **102/102 PASS**. Release APK Firebase/staging build thành công; log private \`artifacts/artemis-remediation/fresh-build.log\`.
- Runner tests: **3/3 PASS**. Driver/actuator/scope targeted unittest: **9/9 PASS**. Suite pytest có sẵn chưa chạy được vì môi trường ARTEMIS chưa cài pytest; không ghi suite đó là PASS.
- ARTEMIS thực tế: các sessions/attempts trong bảng, screenshots và DataEngine SQLite thật. Raw logs ở \`artifacts/artemis-campaigns/${campaign}/\`, được Git ignore. Một số UI tree thiếu text nên ảnh thật và read-back/backend là oracle bổ sung, không tự đổi missing thành PASS.
- API proof dùng Firebase token của tài khoản thử đã đăng nhập trên máy, D1/staging thật. Script oracle chỉ đọc record/media để đối chiếu, không sửa dữ liệu hay bỏ qua đăng nhập trong ứng dụng. Signed URLs/tokens không được đưa vào hồ sơ công khai.
- Dịch vụ/provider/integration khác trong báo cáo cũ vẫn là **baseline lịch sử** (169 local, 15/15 provider, 40/40 staging, 2/2 integration Android). Không gọi các số đó là kiểm thử chạy lại trong phiên này.

## Build, thiết bị và cấu hình

OPPO CPH2637, Android 16/API36. APK đã cài bằng install -r, giữ session và dữ liệu. Version \`${manifest.apk.version}\`, SHA-256 \`${manifest.apk.sha256}\`. Backend staging: \`${manifest.backend}\`.

Source HEAD \`${manifest.sourceCommit}\`, working tree có thay đổi chưa commit. Tool HEAD \`${manifest.toolCommit}\` với patch local được giữ tại \`scripts/patches/artemis-verified-input.patch\`. Baseline model gemini-3.5-flash-lite; các lượt mới chuyển gemini-3.1-flash-lite khi provider trả 429 quota ngày. Model/attempt/session được ghi trong raw metadata/log; không gộp thành một campaign model cố định.

Sự cố môi trường đã gặp: Wireless ADB đổi cổng (hiện dùng mDNS cùng OPPO), cài APK cần chủ máy xác nhận, quota Gemini 429/503, xét duyệt Codex hết hạn mức ở một số thời điểm, một attempt thiếu fallback schema trước khi có action. Các sự cố được giữ trong attempts, không quy thành lỗi ứng dụng hoặc xóa để làm đẹp tỷ lệ.

## Files thay đổi trong remediation

\`scripts/run-artemis-suite.mjs\`, \`scripts/artemis-cases.json\`, \`scripts/export-artemis-evidence.py\`, \`scripts/artemis-campaign.mjs\`, \`scripts/artemis-campaign.test.mjs\`, \`scripts/artemis-cloud-oracle.mjs\`, \`scripts/artemis-review-sheet.py\`, \`scripts/test_artemis_verified_input.py\`, \`scripts/summarize-artemis-remediation.mjs\`, \`scripts/write-artemis-remediation-report.mjs\`, \`scripts/patches/artemis-verified-input.patch\`, hồ sơ Markdown và JSON kết quả. Patch tool sửa \`artemis/drivers/android/adb_driver.py\` và \`artemis/mcp/actuators/adb.py\` trong checkout \`../tools/artemis\`.

Đã pull feature và merge origin/main vào feature tại 0145c47, không có conflict. Code main mới có thay đổi meal delete/BR10, không thuộc APK source 6a5e92f đã đo trên thiết bị. Không chạy lại test sau merge theo yêu cầu. Commit/push hồ sơ remediation được ghi trong Git history. Giữ nguyên các thay đổi ngoài phạm vi, backup Firebase, output DOCX và file khóa PowerPoint.

## Slide và giới hạn

Deck 15 slide cập nhật kết quả báo về và mức hỗ trợ tại \`output/pdf/Longevity_Plate_Lab3_Slides_ARTEMIS_Remediation_20261114.pptx\`. ${assistedNote}

Giới hạn rubric về ảnh Firebase/Cloudinary Console và video người dùng tự quay vẫn theo ASSIGNMENT_ACCEPTANCE.md. Không dùng ảnh minh họa hoặc kết quả local thay screenshot nghiệm thu native/cloud.

Nguồn machine-readable: [${campaign}-summary.json](build-evidence/artemis-remediation/${campaign}-summary.json). Chi tiết 10 ca: [ARTEMIS_CASES.md](ARTEMIS_CASES.md).
`;
writeFileSync(resolve(root,'docs/ARTEMIS_REMEDIATION_STATUS.md'),text);
writeFileSync(resolve(root,'docs/ARTEMIS_FINAL_TECHNICAL_REPORT.md'),text);
const update=`\n<!-- ARTEMIS_REMEDIATION_START -->\n## Remediation thực tế ${stamp}\n\nBaseline giữ **16/30 PASS, 14 FAIL**. Campaign \`${campaign}\` chạy lại riêng 14 lượt FAIL: **${s.rerun.passed}/14 PASS đã xác minh**, ${attempts.length} attempts được giữ. Tổng hợp kế thừa 16 PASS baseline: **${s.combined.passed}/30 (${s.combined.passRatePercent}%)**, còn ${s.combined.unresolved} lượt chưa đạt xác nhận. Đây không phải 30 lượt chạy mới.\n\nChi tiết và giới hạn: [ARTEMIS_REMEDIATION_STATUS.md](ARTEMIS_REMEDIATION_STATUS.md). ${assistedNote} Model, sessions và bằng chứng có trong hồ sơ.\n<!-- ARTEMIS_REMEDIATION_END -->\n`;
for(const file of ['ARTEMIS_RESULTS.md','TEST_RESULTS.md','ASSIGNMENT_ACCEPTANCE.md','DEVICE_ACCEPTANCE.md']){
  const path=resolve(root,'docs',file),previous=readFileSync(path,'utf8');
  writeFileSync(path,previous.replace(/\n<!-- ARTEMIS_REMEDIATION_START -->[\s\S]*?<!-- ARTEMIS_REMEDIATION_END -->\n?/g,'').trimEnd()+'\n'+update);
}
const rcaPath=resolve(root,'docs/ARTEMIS_ROOT_CAUSE_ANALYSIS.md');
const rca=readFileSync(rcaPath,'utf8').replace(/\n<!-- ARTEMIS_REMEDIATION_MATRIX_START -->[\s\S]*?<!-- ARTEMIS_REMEDIATION_MATRIX_END -->\n?/g,'').trimEnd();
writeFileSync(rcaPath,rca+'\n\n<!-- ARTEMIS_REMEDIATION_MATRIX_START -->\n## Trạng thái remediation đã xác minh\n\n'+table+'\n\n'+s.rerun.passed+'/14 lượt FAIL baseline đã có PASS chạy lại. Giữ cả retry và lịch sử đánh giá sửa sai. Xem ARTEMIS_FINAL_TECHNICAL_REPORT.md và JSON summary để đối chiếu từng nguồn.\n<!-- ARTEMIS_REMEDIATION_MATRIX_END -->\n');
console.log(JSON.stringify({verified:s.rerun.passed,combined:s.combined.passed,complete}));
