# Research: AAST LMS Validation — Gaps, Timeline, MVP

**Date**: 2026-04-30 | **Phase**: 0 — Gap Analysis

---

## 1. ARCHITECTURE.md vs CLAUDE.md — Remaining Gaps

### 1.1 Gaps Still Open (not fixed by Task 1 edits)

| Contract in ARCHITECTURE.md | Current State | Action |
|---|---|---|
| Section 7 (Flow A): ZIP-based roster ingestion diagram | CLAUDE.md updated ✅; ARCH.md still shows ZIP | Update ARCH.md in follow-up PR |
| Section 4.1: Caption payload uses `"event"` key | CLAUDE.md updated ✅; ARCH.md still shows `"event"` | Update ARCH.md in follow-up PR |
| Section 4.2: Strike payload uses `"event"` key | CLAUDE.md updated ✅; ARCH.md still shows `"event"` | Update ARCH.md in follow-up PR |
| Section 3.2: `/auth/login` — ARCH.md requires it | CLAUDE.md main.py now imports auth router ✅ | No gap |
| Section 8.5: Offline strike cache | ARCH.md Section 11.3 specifies it | P2-S4-05 added ✅ |
| Section 11.5: Atomic CSV export | ARCH.md specifies `os.replace` pattern | P2-S3-06 updated ✅ |
| Section 11.2: RTSP reconnection | ARCH.md specifies 5 retries | P2-S1-08 added ✅ |

### 1.2 Gaps Fully Resolved

All 7 missing WBS tasks from plan_validation.md Section 2.1 have been added:
- `GET /emotion/confusion-rate` → P2-S3-08 (moved from Phase 3)
- Offline strike cache → P2-S4-05
- Atomic CSV → P2-S3-06 updated
- RTSP reconnection → P2-S1-08
- Auto-submit 60s polling → P4-S1-03 expanded
- `POST /session/broadcast` → P2-S3-09
- Real JWT auth → P2-S3-10

---

## 2. Timeline Assessment — Single Developer Reality

### 2.1 Original Timeline Assumptions

The WBS was designed for 4 developers (S1–S4) working in parallel over 16 weeks.
One developer must do all 4 roles sequentially (or partially parallel).

### 2.2 Task Count by Phase

| Phase | S1 Tasks | S2 Tasks | S3 Tasks | S4 Tasks | Total |
|---|---|---|---|---|---|
| Phase 1 | 5 | 7 | 7 | 5 | 24 |
| Phase 2 | 8 | 13 | 10 | 5 | 36 |
| Phase 3 | 4 | 4 | 4 | 3 | 15 |
| Phase 4 | 4 | 3 | 3 | 2 | 12 |
| Integration | — | — | — | — | 3 |
| **Total** | **21** | **27** | **24** | **15** | **90 tasks** |

### 2.3 Honest Timeline (single developer, full scope)

At 2–3 tasks/week (realistic for a student balancing coursework):
- 90 tasks ÷ 2.5 avg = **36 weeks** — more than double the original 16-week plan.

**Decision: Treat 16 weeks as the target for MVP scope only.**

### 2.4 Critical Path for a Single Developer

Week 1–2: Data contract + DB + all mock endpoints (S3 tasks) — enables all other work
Week 3–4: Vision pipeline (S1) — core differentiator; start as early as possible
Week 5–8: Shiny admin panels + engagement module (S2) — most time-consuming
Week 9–12: React Native screens + real endpoints (S4 + S3) — MVP student experience
Week 13–16: AI features + exam proctoring (S1 + Gemini) — polish/extras

---

## 3. Google Drive Photo Download — Technical Decision

### 3.1 Options Evaluated

**Option A: Service Account (Drive API)**
- Requires `gcloud_key.json` already in the repo
- Works for private files
- 5-10 lines of auth code + `google-api-python-client`

**Option B: Direct URL download (public share link)**
- `https://drive.google.com/uc?export=download&id={file_id}`
- Works only if sharing is set to "Anyone with link"
- 2-3 lines with `requests.get()`
- No service account needed

**Decision: Option B** — The StudentPicsDataset.xlsx photos are shared by the university,
so links should be accessible. Fall back to Option A (service account already configured)
if URLs return 403.

**Rationale**: Simpler code path, no extra dependencies. The service account in `gcloud_key.json`
remains available as fallback.

**Risk**: If Drive links require authentication, Option A is the fallback. The `roster.py`
implementation should log a warning when a download returns non-image content.

---

## 4. Hosting Decision — Railway vs. DigitalOcean

**Decision: DigitalOcean $200 student credit** (recommended over Railway free tier)

**Rationale**:
- Railway free tier sleeps after 30 min inactivity → cold start delays during class
- DigitalOcean $6/month Basic Droplet (1GB RAM, 25GB SSD) stays awake 24/7
- $200 credit = 33 months at $6/month — covers the full academic year
- Persistent disk means SQLite file survives redeploys (Railway resets disk on redeploy)
- Self-host Shiny Server on same droplet → eliminates shinyapps.io 25h/month limit

**Setup**: DigitalOcean Ubuntu 22.04 droplet → Docker Compose with FastAPI + Shiny containers.

**Alternatives considered**: Render (no persistent disk on free tier), Heroku (removed free tier),
Azure (overly complex setup for a student project).

---

## 5. SQLite Sufficiency Analysis

```
Worst case per lecture:
  127 students × 12 emotion samples/min × 60 min = 91,440 emotion_log rows
  127 students × 1 attendance row = 127 attendance_log rows
  12 transcript rows/min × 60 min = 720 transcripts rows
  Total: ~92,287 rows per lecture

SQLite WAL mode: handles ~10,000-50,000 writes/sec on SSD
Vision pipeline write rate: ~25 writes/5s = 5 writes/sec (well under limit)
```

**Decision: SQLite is sufficient for this scale.** Bottleneck will be ML inference speed,
not database writes.
