# Bảng xếp hạng DP theo năm (LB-02)

Base URL `/api/v1`. Header `X-Tenant-Code`, `Authorization: Bearer <token>`. Học viên (M) và mọi staff (S) đều gọi được; không có quyền thì 403.

## GET /leaderboard/dp

Bảng xếp hạng DP của một mùa giải (một năm dương lịch, theo giờ Việt Nam).

| Query | Kiểu | Mặc định | Ghi chú |
|---|---|---|---|
| year | int 2000-2200 | năm hiện tại | Năm của mùa giải |
| top | int 1-50 | 10 | Lấy đến **vị trí** này (không phải số dòng) |

```json
{
  "data": {
    "season": { "year": 2026, "startsAt": "2025-12-31T17:00:00.000Z", "endsAt": "2026-12-31T17:00:00.000Z", "status": "ACTIVE" },
    "top": 10,
    "totalRanked": 37,
    "items": [
      { "position": 1, "memberId": "6b1f…", "fullName": "Nguyễn Văn A", "avatarUrl": null,
        "rank": { "code": "THE_FORGED", "name": "Người được tôi luyện" }, "dpTotal": 5120, "isMe": false },
      { "position": 2, "memberId": "9c2d…", "fullName": "Trần Thị B", "avatarUrl": null,
        "rank": { "code": "THE_DISCIPLINED", "name": "Người có kỷ luật" }, "dpTotal": 4300, "isMe": true },
      { "position": 2, "memberId": "a41e…", "fullName": "Lê Văn C", "avatarUrl": null,
        "rank": null, "dpTotal": 4300, "isMe": false }
    ],
    "me": { "position": 2, "dpTotal": 4300 }
  }
}
```

- `status`: `UPCOMING` (chưa bắt đầu, `items` rỗng), `ACTIVE`, `CLOSED`. Mùa đã đóng vẫn trả bảng tính lại từ sổ DP.
- `totalRanked`: số học viên có DP trong mùa (cả bảng, không chỉ top).
- `me`: chỗ đứng của chính học viên đang xem, **kể cả khi ngoài top**. `null` với staff và với học viên chưa có DP trong mùa hoặc không còn hoạt động. `isMe` đánh dấu dòng của mình trong `items`.
- `rank`: hạng hiện tại của học viên (không phải hạng lúc cuối mùa), `null` nếu chưa có.

### Quy tắc tính

- **DP năm** = tổng `dpAmount` của các giao dịch `POSTED` có `occurredAt` trong `[startsAt, endsAt)`. Không tính số dư đầu kỳ (`OPENING`). Điều chỉnh tay (`MANUAL_ADJUSTMENT`), thưởng Rank Trial, thử thách... đều tính.
- **Đảo giao dịch:** dòng `REVERSAL` được tính vào mùa của giao dịch gốc, không phải mùa lúc đảo. Cộng nhầm rồi đảo sau Tết vẫn triệt tiêu đúng trong năm cũ.
- **Chỉ học viên đang hoạt động** (`status = ACTIVE`); tạm khóa (`FROZEN`), ngừng (`INACTIVE`) và tài khoản đã gộp trùng không có trong bảng.
- **Đồng hạng:** cùng DP thì cùng vị trí, vị trí kế tiếp nhảy cách (1, 2, 2, 4). Cùng vị trí xếp theo tên rồi theo id. Đồng hạng ở vị trí cuối của `top` thì lấy hết, nên `items` có thể dài hơn `top`.
- Học viên có DP ròng ≤ 0 không có trong bảng.

### Lỗi

| Mã | HTTP | Khi nào |
|---|---|---|
| `LEADERBOARD_SEASON_NOT_FOUND` | 404 | Chưa có mùa giải của năm yêu cầu |
| `VALIDATION_ERROR` | 400 | `year` / `top` sai kiểu hoặc ngoài khoảng |
