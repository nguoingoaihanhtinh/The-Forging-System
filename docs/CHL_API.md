# CHL — Challenge APIs và tiến độ tự động

Base URL: `/api/v1`. Các API member yêu cầu Bearer token, tenant header và role `MEMBER`.

## CHL-01: Quản trị Challenge

Chỉ `ADMIN` / `SUPER_ADMIN`.

| Method | Path | Mục đích |
|---|---|---|
| POST | `/admin/challenges` | Tạo Challenge ở `DRAFT` |
| PATCH | `/admin/challenges/:challengeId` | Sửa Challenge, yêu cầu `reason` |
| GET | `/admin/challenges` | Danh sách/search/filter/phân trang |
| GET | `/admin/challenges/:challengeId` | Chi tiết Challenge |

Challenge dùng `code`, `title`, `description`, `challengeType`, `context`, `target`, `rewardDp`, `rewardMarks`, `startsAt`, `endsAt`. `status`, actor và tenant luôn do server quản lý. Khi đã có participation, không thể sửa điều kiện, phần thưởng hoặc thời hạn; chỉ được sửa metadata. Các mutation ghi audit `CHALLENGE_CREATED` / `CHALLENGE_UPDATED`.

## CHL-02: Mở/đóng Challenge

```http
PATCH /api/v1/admin/challenges/:challengeId/status
```

```json
{ "enabled": true, "reason": "Mở thử thách tháng 10" }
```

`enabled=true` chuyển `DRAFT` hoặc `CLOSED` sang `OPEN` khi Challenge hợp lệ và chưa hết hạn; `enabled=false` chuyển `OPEN` sang `CLOSED`. `CANCELLED` không thể mở lại. `enabled` là field suy ra từ `status === OPEN`, không có cột riêng. Mutation ghi audit `CHALLENGE_ENABLED` / `CHALLENGE_DISABLED`.

## CHL-03: Danh sách Challenge đang mở

| Method | Path |
|---|---|
| GET | `/me/challenges` |
| GET | `/me/challenges/open` |
| GET | `/challenges` |
| GET | `/challenges/open` |

Query tùy chọn: `period` hoặc `challengeType` (`DAILY`, `WEEKLY`, `MONTHLY`, `EVENT`), `context` (`SESSION`, `WORKSHOP`, `EXAM`), `q`, `page` và `limit` (mặc định 20, tối đa 100).

Chỉ trả Challenge `OPEN`, chưa hết hạn; sắp xếp `endsAt ASC, id DESC`. Mỗi row bao gồm Challenge cùng `participationId`, `participationStatus`, `progressValue`, `joinedAt` và `evidenceUrl` nếu member đã tham gia. Response list dùng `{ data, meta }` với `page`, `limit`, `total`, `totalPages`.

## CHL-04: Tham gia Challenge

| Method | Path |
|---|---|
| POST | `/me/challenges/:challengeId/join` |
| POST | `/challenges/:challengeId/join` |

Không có request body. Challenge phải tồn tại, `OPEN`, trong thời gian `[startsAt, endsAt)` và member chưa tham gia. Thành công trả `201` participation có `status: JOINED`, `progressValue: 0`. Join được audit `CHALLENGE_JOINED`, không phát DP/Marks và không tự tăng progress.

| HTTP | Code | Tình huống |
|---|---|---|
| 400 | `VALIDATION_ERROR` | `challengeId` không phải UUID |
| 409 | `CHALLENGE_NOT_OPEN` | Challenge chưa mở/đã đóng |
| 409 | `CHALLENGE_CLOSED` | Chưa bắt đầu hoặc đã hết hạn |
| 409 | `CHALLENGE_ALREADY_JOINED` | Member đã tham gia |

## CHL-05: Cập nhật tiến độ tự động

CHL-05 không mở public HTTP endpoint. Tiến độ được cập nhật trong cùng transaction khi attendance được xác nhận qua domain event `ATTENDANCE_CONFIRMED`.

### Điều kiện cập nhật

- Participation phải ở trạng thái `JOINED`.
- Challenge phải `OPEN`, đúng thời hạn `[startsAt, endsAt)` tại thời điểm xác nhận.
- Context được suy ra từ attendance: `isExam=true` → `EXAM`; `sessionType=WORKSHOP` → `WORKSHOP`; các session còn lại → `SESSION`.
- Mỗi `attendanceId` chỉ tăng một lần cho mỗi participation. Bảng `challenge_progress_events` bảo đảm retry event không tăng lặp.

### Kết quả

- `progressValue` tăng tối đa đến `target`.
- Khi chạm `target`, participation chuyển `JOINED → AWAITING_COACH` và ghi `completedAt`.
- Chưa nộp bằng chứng, chưa có coach quyết định, không phát DP/Marks trong CHL-05. Các việc này thuộc CHL-06.
- Mỗi lần tăng tiến độ/đạt mục tiêu được ghi audit với nguồn `ATTENDANCE_CONFIRMED` và `attendanceId`.

### Tích hợp attendance

CHL-05 đã đăng ký listener cho `DomainEvents.ATTENDANCE_CONFIRMED`. Module xác nhận attendance cần emit event này sau khi Coach xác nhận để kích hoạt cập nhật tự động.

## CHL-06: Nộp bằng chứng và Coach duyệt

| Method | Path | Quyền |
|---|---|---|
| POST | `/me/challenges/:challengeId/evidence` | MEMBER |
| GET | `/staff/challenges/participations` | COACH, HEAD_COACH, ADMIN, SUPER_ADMIN |
| POST | `/staff/challenges/participations/:participationId/approve` | COACH, HEAD_COACH, ADMIN, SUPER_ADMIN |

Nộp bằng chứng:

```json
{ "evidenceUrl": "http://localhost:4000/files/challenges/proof.jpg" }
```

- Chỉ participation của chính member, đang `AWAITING_COACH`, mới được nộp hoặc thay bằng chứng.
- URL phải là file đã tải qua hệ thống, dưới `${PUBLIC_BASE_URL}/files/`.
- Coach chỉ duyệt participation `AWAITING_COACH` đã có bằng chứng. Duyệt lặp trả `duplicate: true`.
- Duyệt chuyển `AWAITING_COACH → REWARDED`, ghi Coach/thời điểm và phát reward snapshot `rewardDp`/`rewardMarks` qua ledger với idempotency key theo participation.
- Khi member đã đạt `challenge.monthly_reward_limit` trong tháng, participation vẫn `REWARDED` nhưng `isLimited=true` và không phát DP/Marks.
- Audit: `CHALLENGE_EVIDENCE_SUBMITTED`, `CHALLENGE_APPROVED` hoặc `CHALLENGE_APPROVED_LIMITED`.

Hàng chờ duyệt của Coach:

```http
GET /api/v1/staff/challenges/participations?status=AWAITING_COACH&evidence=SUBMITTED&page=1&limit=100
```

- Query tùy chọn: `status` (`JOINED`, `AWAITING_COACH`, `REWARDED`, `EXPIRED`), `evidence` (`SUBMITTED`, `PENDING`), `q` (tên/mã học viên hoặc tên Challenge), `page`, `limit`.
- Kết quả sắp `AWAITING_COACH` trước, sau đó theo `completedAt` tăng dần. Mỗi row có `id` (participationId), `challengeTitle`, `challengeType`, `target`, `memberCode`, `memberFullName`, `progressValue`, `evidenceUrl`, `status`.

UI:

- Member: thẻ Challenge `AWAITING_COACH` hiện nút **Nộp bằng chứng**, mở bottom sheet chọn/upload ảnh qua `EvidencePhotoPicker` rồi gọi `POST /me/challenges/:challengeId/evidence`.
- Coach: tab **Challenge** tại `/coach/challenge` gọi danh sách trên, hiển thị ảnh minh chứng và nút **Duyệt và phát thưởng** (xác nhận trước khi gọi API approve).

Mã nguồn:

- `mobile/lib/features/challenges/presentation/current_challenges_screen.dart`
- `mobile/lib/features/coach_challenges/domain/challenge_review.dart`
- `mobile/lib/features/coach_challenges/data/challenge_review_repository.dart`
- `mobile/lib/features/coach_challenges/presentation/challenge_review_tab.dart`

## Kiểm tra

```sh
npm run typecheck
npm run lint
npm run build
npm test
```

## CHL-09: Danh sách thử thách học viên

Màn **Thử thách** tại `/student/challenges` hiển thị Challenge đang mở qua `GET /api/v1/me/challenges`.

- Lọc tất cả, hằng ngày, hằng tuần, hằng tháng và sự kiện.
- Hiển thị mục tiêu, phần thưởng DP/Marks, thời điểm kết thúc và trạng thái tham gia.
- Hỗ trợ pull-to-refresh, retry và phân trang.
- Chỉ đọc danh sách/trạng thái; thao tác tham gia thuộc CHL-04.

Mã nguồn:

- `mobile/lib/features/challenges/domain/open_challenge.dart`
- `mobile/lib/features/challenges/data/open_challenge_repository.dart`
- `mobile/lib/features/challenges/presentation/open_challenge_providers.dart`
- `mobile/lib/features/challenges/presentation/open_challenges_screen.dart`

## CHL-10: Thẻ thử thách hiện tại

Màn **Thử thách** tại `/student/challenges` hiển thị các Challenge đã tham gia, lấy từ `GET /api/v1/me/challenges` với `participationId`.

- Hiển thị loại/trạng thái, tiến độ `progressValue / target`, hạn kết thúc và phần thưởng DP/Marks.
- Challenge `AWAITING_COACH` có nút **Nộp bằng chứng** (CHL-06).
- Có trạng thái rỗng, retry và kéo để làm mới.
- Chỉ theo dõi tiến độ; tham gia thuộc CHL-04 và tăng progress thuộc CHL-05.

Mã nguồn:

- `mobile/lib/features/challenges/domain/current_challenge.dart`
- `mobile/lib/features/challenges/data/current_challenge_repository.dart`
- `mobile/lib/features/challenges/presentation/current_challenge_providers.dart`
- `mobile/lib/features/challenges/presentation/current_challenges_screen.dart`
