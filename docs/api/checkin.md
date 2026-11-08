# Check-in (CHK-01 đến CHK-05)

Base URL `/api/v1`. Header `Authorization: Bearer <token>`. Quy ước chung xem [`README.md`](README.md).

Học viên tự check-in bằng cách quét (hoặc nhập) **mã xoay vòng** hiển thị ở màn hình phòng tập. Lễ tân có thể check-in hộ khi học viên không tự làm được. Check-in xong buổi ở trạng thái **chờ Coach xác nhận**; DP/Marks chỉ được cộng sau khi Coach xác nhận.

| Việc | API | Ai |
|---|---|---|
| Lấy mã đang hiển thị (màn hình quầy) | `GET /branches/:branchId/checkin-code` | FD |
| Buổi hôm nay có thể check-in (học viên) | `GET /me/checkin/sessions` | M |
| Check-in (học viên) | `POST /me/checkin` | M |
| Buổi hôm nay của một học viên (lễ tân) | `GET /members/:memberId/checkin/sessions` | FD |
| Check-in hộ (lễ tân) | `POST /members/:memberId/checkin` | FD |

## Mã xoay vòng

`GET /branches/:branchId/checkin-code`: lễ tân chỉ lấy được mã của **chi nhánh mình**, admin lấy mọi chi nhánh.

```json
{ "data": {
  "branchId": "c0a8…", "branchCode": "Q1", "qrVersion": "1",
  "payload": "HVP|Q1|1|58739402|3fa9c01b7d2e44a0",
  "shortCode": "482913",
  "ttlSeconds": 30,
  "expiresAt": "2026-11-02T10:50:30.000Z",
  "serverTime": "2026-11-02T10:50:12.000Z"
} }
```

- Màn hình vẽ `payload` thành QR và hiện `shortCode` cho người không quét được.
- Đếm ngược theo `expiresAt - serverTime` (đồng hồ máy chủ, không dùng giờ máy tính bảng), hết giờ thì gọi lại để lấy mã mới. Mã đổi mỗi `ttlSeconds` (mặc định 30 giây).
- Mã vẫn được chấp nhận thêm một khung (30 đến 60 giây sau khi phát) để bù độ trễ mạng. **Nhiều học viên dùng chung một mã**, không phải mã dùng một lần.
- Đổi QR chi nhánh (`POST /admin/branches/:id/qr/rotate`) làm mọi mã đã phát mất hiệu lực.

## Buổi hôm nay có thể check-in

`GET /me/checkin/sessions` (học viên) và `GET /members/:memberId/checkin/sessions` (lễ tân; lễ tân chỉ thấy buổi ở chi nhánh mình, admin thấy tất cả).

```json
{ "data": {
  "date": "2026-11-02",
  "eligibility": { "canCheckin": true, "code": null, "message": null },
  "sessions": [ {
    "sessionId": "…", "classId": "…", "title": "Evening", "sessionType": "GROUP", "isExam": false,
    "startsAt": "2026-11-02T11:00:00.000Z", "endsAt": "2026-11-02T12:00:00.000Z",
    "branch": { "id": "…", "name": "HVP Boxing - The Corner" },
    "coach": { "id": "…", "fullName": "Nguyễn Văn B" },
    "checkin": {
      "state": "OPEN", "canCheckin": true, "reason": null, "message": null,
      "opensAt": "2026-11-02T10:15:00.000Z", "closesAt": "2026-11-02T11:30:00.000Z", "checkedInAt": null
    }
  } ]
} }
```

`checkin.state`: `OPEN` (check-in được), `NOT_YET_OPEN`, `CLOSED`, `CHECKED_IN` (đã check-in, chờ Coach hoặc đã được đánh giá), `OVERLAPS_CHECKED_IN` (trùng giờ với một buổi đã check-in), `BLOCKED` (tài khoản hoặc gói không cho phép). Khi không check-in được, `reason` là một mã trong bảng lỗi bên dưới và `message` là câu hiển thị.

Cửa sổ check-in tự động: mở **45 phút trước** giờ bắt đầu, đóng **30 phút sau** giờ bắt đầu. Lễ tân check-in hộ được đến **hết buổi**.

## Học viên check-in

`POST /me/checkin`

```json
{ "payload": "HVP|Q1|1|58739402|3fa9c01b7d2e44a0", "sessionId": "…" }
```

Gửi **đúng một** trong `payload` (nội dung QR) hoặc `shortCode` (6 chữ số nhập tay). `sessionId` tùy chọn: bỏ qua thì hệ thống tự chọn buổi ở chi nhánh vừa quét; nhập tay thì thử với các chi nhánh học viên có buổi hôm nay. Tối đa 15 lần thử mỗi phút mỗi tài khoản.

Ba kết quả thành công, FE phân biệt bằng `status` và HTTP code:

1. **201** `status: "CHECKED_IN"`, `alreadyCheckedIn: false`: vừa check-in. Đã trừ một buổi của gói.
2. **200** `status: "CHECKED_IN"`, `alreadyCheckedIn: true`: đã check-in từ trước, không trừ thêm.
3. **200** `status: "CHOOSE_SESSION"`: có nhiều buổi đang mở ở chi nhánh này. Hiện danh sách `sessions` cho học viên chọn rồi gửi lại **cùng mã** kèm `sessionId`. Mã chỉ còn dùng được 30 đến 60 giây nên nếu chờ lâu phải quét lại.

```json
{ "data": {
  "status": "CHECKED_IN", "alreadyCheckedIn": false,
  "checkedInAt": "2026-11-02T10:50:12.000Z",
  "session": { "sessionId": "…", "title": "Evening", "startsAt": "…", "endsAt": "…", "branch": { "id": "…", "name": "…" } },
  "sessionsRemaining": 31,
  "message": "Check-in thành công. Buổi tập đang chờ Coach xác nhận - điểm chỉ được cộng sau khi Coach xác nhận."
} }
```

`sessionsRemaining` là `null` với gói không giới hạn buổi.

## Lễ tân check-in hộ

`POST /members/:memberId/checkin`

```json
{ "sessionId": "…", "evidenceUrl": "https://api.hvp.vn/files/hvp/evidence/2026-11/x.jpg" }
```

- `evidenceUrl` **bắt buộc**: ảnh học viên tại quầy, lấy từ `POST /uploads?purpose=evidence`.
- Lễ tân chỉ làm cho buổi ở chi nhánh mình, admin cho mọi chi nhánh.
- Vẫn áp dụng đủ điều kiện như học viên tự check-in (tài khoản, gói, trùng giờ); lễ tân không bỏ qua được.
- Kết quả cùng dạng như trên (201 hoặc 200 nếu đã check-in).

## Lỗi

Mọi lỗi nghiệp vụ có dạng `{ "error": { "code", "message", "details": { "action", … } } }`. FE `switch` theo `code`, hiển thị `message` và dựa vào `details.action` để chọn nút tiếp theo:

| `action` | Ý nghĩa cho app |
|---|---|
| `RESCAN` | Quét lại mã ở màn hình phòng tập |
| `WAIT` | Chưa đến giờ, quay lại sau (`details.opensAt`) |
| `ASK_FRONT_DESK` | Nhờ lễ tân hỗ trợ (lễ tân có thể check-in hộ) |
| `RENEW_PACKAGE` | Cần gia hạn gói tập |
| `GO_TO_BRANCH` | Buổi ở chi nhánh khác (`details.branches`) |
| `ATTACH_PHOTO` | Lễ tân cần chụp hoặc đính kèm ảnh |
| `NONE` | Chỉ hiển thị thông báo |

| `code` | HTTP | `action` | Khi nào |
|---|---|---|---|
| `CHECKIN_CODE_INVALID` | 400 | `RESCAN` | Mã sai, không đọc được, đã đổi QR chi nhánh, hoặc mã 6 số không khớp |
| `CHECKIN_CODE_EXPIRED` | 422 | `RESCAN` | Mã đã quá hạn |
| `NO_SESSION_TODAY` | 422 | `NONE` | Hôm nay học viên không có buổi nào |
| `CHECKIN_WRONG_BRANCH` | 422 | `GO_TO_BRANCH` | Mã của chi nhánh khác với buổi (`details.branches`: nơi diễn ra buổi tập) |
| `CHECKIN_SESSION_NOT_ELIGIBLE` | 404 | `NONE` | `sessionId` không nằm trong các buổi hôm nay của học viên |
| `OVERLAPS_CHECKED_IN` | 422 | `NONE` | Đã check-in một buổi khác trùng khung giờ |
| `NOT_YET_OPEN` | 422 | `WAIT` | Chưa đến giờ mở (`details.opensAt`) |
| `CHECKIN_CLOSED` | 422 | `ASK_FRONT_DESK` | Đã hết giờ check-in (`details.closesAt`) |
| `ACCOUNT_INACTIVE` | 422 | `ASK_FRONT_DESK` | Tài khoản không hoạt động |
| `ACCOUNT_RESTRICTED` | 422 | `ASK_FRONT_DESK` | Tài khoản đang đóng băng |
| `MEMBERSHIP_INVALID` | 422 | `RENEW_PACKAGE` | Chưa có gói, gói hết hạn hoặc hết buổi |
| `CHECKIN_EVIDENCE_REQUIRED` | 400 | `ATTACH_PHOTO` | Check-in hộ thiếu ảnh minh chứng |
| `INVALID_CHECKIN_EVIDENCE` | 400 | `ATTACH_PHOTO` | Ảnh không phải file do hệ thống lưu |
| `CHECKIN_BRANCH_FORBIDDEN` | 403 | `NONE` | Lễ tân thao tác ở chi nhánh không phải của mình |
| `BRANCH_INACTIVE` | 422 | `NONE` | Chi nhánh ngừng hoạt động nên không phát mã |

Ngoài ra là các lỗi chung của API: 401 chưa đăng nhập, 403 sai vai trò, 404 `NOT_FOUND` (chi nhánh hoặc học viên không tồn tại), 400 `VALIDATION_ERROR` (sai dạng body), 429 quá số lần thử.
