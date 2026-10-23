# Fork talker cho VMap — nhánh `vmap/grouping`

Fork của monorepo Frezyx/talker tại tag upstream **v5.1.20**. Mục tiêu: mỗi API call hiển thị thành **một item** trên `TalkerScreen` (request + response/error + duration).
Spec đầy đủ: `docs/vmap/grouping-spec.md`. Mã yêu cầu (D1–D6, F1–F12, A1–A10, NF1–NF9) tham chiếu theo spec đó.

## Phạm vi fork
Chỉ sửa 2 package; các package khác giữ nguyên upstream.

- `packages/talker_dio_logger` (D1–D6): sinh request id cho mỗi lần gửi.
  - Code mới: `lib/talker_dio_request_id.dart`.
  - Điểm nối: `talker_dio_logger_interceptor.dart` (onRequest), `talker_dio_logger_settings.dart` (5 setting mới), `dio_logs.dart` (field `requestId` trên 3 class log).
- `packages/talker_flutter` (F1–F12): gom log theo key ở tầng danh sách, không phụ thuộc dio.
  - Code mới: `lib/src/grouping/` (`TalkerLogGrouper`, `TalkerLogGroup`, `TalkerLogItem`, `TalkerGroupCard`).
  - Điểm nối: `lib/src/ui/talker_view.dart`, `lib/src/ui/talker_screen.dart` (tham số `grouper`), `lib/src/src.dart` (export).

Phía app (A1–A10: `DioGrouper`, card HTTP, màn chi tiết, mask) **không** nằm ở repo này, mà ở app `vmap`.

## Quy tắc khi sửa
- Diff trong file gốc phải nhỏ (talker_flutter < 150 dòng, talker_dio_logger < 80 dòng); code mới đặt trong file riêng.
- Không truyền `grouper` / không bật header → hành vi giống hệt upstream (NF4). Test upstream không được sửa.
- Chỉ thêm tham số/field optional (NF5); không thêm dependency (NF6).

## Quyết định đã chốt
- Logger `enabled: false` → không sinh id.
- Id không in trong "Extra" của console (để không vỡ test upstream); xem id qua `printRequestId`.
- Retry luôn sinh id mới; không có chế độ "giữ id cũ" (D3).
- Share/copy giữ thứ tự thời gian như upstream; nhóm nằm ở vị trí log đầu tiên.
- `share_plus` nới về `>=10.1.4 <14` và dùng API `Share.shareXFiles` cũ (có ở 10–13), để app giữ được share_plus 10; bản 13.1+ kéo `win32` 6 xung đột `package_info_plus` 9.
- `TalkerScreen(canShareLogsFile: false)` ẩn "Share logs file" (app vmap ẩn để log không rời máy); mặc định như upstream.
- `filterKeys`: chip luôn hiện theo thứ tự đó (kể cả đếm 0), trước các key khác có trong log.
- Filter key của nhóm xét trên log CUỐI (trạng thái hiện tại của call), search xét mọi log con (F5).
- `groupKeyOf` / `buildGroup` / `groupText` throw → log hiển thị như log đơn, `debugPrint` lỗi.

## Kiểm tra
```sh
cd packages/talker_dio_logger && dart analyze && dart test     # 70 test
cd packages/talker_flutter && flutter analyze && flutter test  # 16 test
```
`flutter pub get` (Flutter 3.47) tự sửa `analysis_options.yaml` và file sinh trong `example/` — không commit các thay đổi đó.

## Còn lại
- Tag `v5.1.20-vmap.1`.
- Phía app trong `vmap` (A1–A10), khai báo `dependency_overrides` trỏ về fork này.
- PR lên upstream: request id (dio) trước; grouping sau 2 sprint ổn định. Bỏ `CLAUDE.md` và `docs/vmap/` khỏi PR upstream.
