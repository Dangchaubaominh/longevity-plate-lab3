"""Read real ARTEMIS DataEngine evidence; never invent a missing observation.

Raw UI text can contain private account data and remains in ignored artifacts.
The exported review contains case IDs, hashes and criterion booleans only.
"""
import json
from pathlib import Path
import sqlite3
import unicodedata

root = Path(__file__).resolve().parents[1]
runs = root / "artifacts/artemis-runs"
results = json.loads((runs / "suite-results.json").read_text(encoding="utf8"))
db = sqlite3.connect(f"file:{(runs / 'traces/data_engine.db').as_posix()}?mode=ro", uri=True)

def normalize(value):
    return unicodedata.normalize("NFC", value)

reviews = []
for result in results:
    session = result.get("session")
    steps = db.execute("SELECT step_number,pre_image_name,post_image_name,action_taken FROM steps WHERE session_id=? ORDER BY step_number", (session,)).fetchall()
    texts, packages, actions, images = [], set(), [], set()
    for number, pre, post, action in steps:
        try:
            actions.append(json.loads(action))
        except (TypeError, ValueError):
            pass
        for name in [pre, post]:
            if not name or name in images:
                continue
            images.add(name)
            row = db.execute("SELECT ui_tree FROM images WHERE image_name=?", (name,)).fetchone()
            try:
                nodes = json.loads(row[0]) if row else []
            except (TypeError, ValueError):
                nodes = []
            if not isinstance(nodes, list):
                continue
            for node in nodes:
                texts.extend([node.get("text", ""), node.get("content-desc", "")])
                packages.add(node.get("package", ""))
    visible = normalize("\n".join(texts))
    targets = normalize("\n".join(str(a.get("target_text", "")) for a in actions))
    criteria = {
        "hasRecordedSteps": bool(steps),
        "hasRealImages": bool(images),
        "goalValidationVisible": "Hãy chọn ít nhất một mục tiêu" in visible,
        "mealTypeErrorVisible": "Hãy chọn loại bữa" in visible,
        "mealDescriptionErrorVisible": "Hãy nhập món ăn trước khi lưu" in visible,
        "discardDialogVisible": "Bỏ thay đổi" in visible,
        "replacementDialogVisible": "Thay thế món hiện tại" in visible,
        "cancelActionRecorded": "Hủy" in targets,
        "noMatchQueryVisible": "ARTEMIS_NO_SUCH_ARTICLE" in visible,
        "nativeGoogleUiObserved": any("google.android.gms" in p for p in packages),
        "nativeBrowserObserved": any("chrome" in p or "browser" in p for p in packages),
        "nativePhotoPickerObserved": any("providers.media" in p or "photopicker" in p or "google.android.apps.photos" in p for p in packages),
        "galleryButtonVisible": "Chọn từ thư viện" in visible,
        "galleryButtonClicked": "Chọn từ thư viện" in targets,
    }
    case = result["caseId"]
    required = ["hasRecordedSteps", "hasRealImages"]
    required += {
        "AR02": ["goalValidationVisible"],
        "AR04": ["mealTypeErrorVisible", "mealDescriptionErrorVisible"],
        "AR05": ["discardDialogVisible"],
        "AR07": ["replacementDialogVisible", "cancelActionRecorded"],
        "AR08": ["noMatchQueryVisible"],
        "AR10": ["nativeBrowserObserved"],
        "AR13": ["nativePhotoPickerObserved", "galleryButtonClicked"],
    }.get(case, [])
    missing = [key for key in required if not criteria[key]]
    reviews.append({
        "name": result["name"], "session": session,
        "agentReportedSuccess": result["reportedSuccess"],
        "recordedSteps": len(steps), "imageCount": len(images),
        "criteria": criteria, "missingObservations": missing,
        "observationChecksPass": not missing,
        "boundary": "UI observation checks; verify saved records/cloud ownership separately."
    })
output = runs / "observation-review.json"
output.write_text(json.dumps(reviews, ensure_ascii=False, indent=2) + "\n", encoding="utf8")
print(json.dumps({"sessions": len(reviews), "reviewRequired": [{"name": r["name"], "missing": r["missingObservations"]} for r in reviews if r["missingObservations"]]},ensure_ascii=True))
