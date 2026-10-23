Spec: Gộp log API request/response trong Talker (fork talker_flutter + talker_dio_logger)

Oct 22, 2026
 · 
@Someone


Bối cảnh & mục tiêu
Mỗi API call phải hiển thị thành một item duy nhất trên TalkerScreen, gồm request, response hoặc error, và thời gian xử lý. Giải pháp là fork 2 package: talker_dio_logger tự sinh id cho mỗi request, còn talker_flutter gom log theo key ở tầng danh sách. Cách vẽ một HTTP call nằm trong app VETC.

Hiện tại talker_dio_logger ghi 2 log tách rời cho mỗi call: DioRequestLog, sau đó là DioResponseLog hoặc DioErrorLog. Cách ghi này gây ra 3 vấn đề:

Khi nhiều call chạy song song, QA và dev phải tự dò xem response nào thuộc request nào.

Mỗi call chiếm 2 slot trong maxHistoryItems, nên history bị đẩy ra nhanh gấp đôi.

Report được share ra ngoài khó đọc.

talker_flutter 5.1.20 chưa hỗ trợ gộp log (tính năng "Logs grouping" vẫn nằm trong roadmap). Tham số itemsBuilder chỉ thay được widget của từng item, không sửa được filter, search và share ở cấp danh sách. Vì vậy cần fork.

Mục tiêu

G1. Mỗi call chỉ là một item, có trạng thái pending, success hoặc error.

G2. Filter, search, copy và share hoạt động đúng theo nhóm.

G3. Diff so với upstream đủ nhỏ để rebase mỗi lần nâng version và có thể gửi PR lên repo gốc.

Phạm vi
Spec này chỉ áp dụng cho màn log debug (TalkerScreen) trong các build nội bộ: dev, staging và QA.

Trong phạm vi

Fork talker_dio_logger 5.1.20: tự sinh request id, với tên key cấu hình được (mặc định talker-request-id), và lưu id này vào từng log HTTP.

Fork talker_flutter 5.1.20: thêm interface TalkerLogGrouper, gom nhóm trong TalkerView, filter/search/copy/share theo nhóm, và widget mặc định TalkerGroupCard.

Phía app: DioGrouper, card HTTP call, màn chi tiết 3 tab, che dữ liệu nhạy cảm, và cố định thứ tự các interceptor.

Ngoài phạm vi

Thay đổi output console. Log trên terminal vẫn tách request và response như hiện tại.

Fork package core talker hay thêm groupKey vào TalkerData. Chỉ cân nhắc nếu upstream nhận PR.

Fork các logger khác: http, chopper, grpc.

Gộp log của BLoC, route hay WebView MiniApp. Interface có hỗ trợ nhưng chưa triển khai trong đợt này.

Đưa TalkerScreen vào build production.

Thuật ngữ
Thuật ngữ

Ý nghĩa

Log đơn

Một phần tử TalkerData trong talker.history

Nhóm (group)

Tập các log đơn có cùng groupKey, hiển thị thành 1 item

groupKey

Chuỗi do TalkerLogGrouper trả về; null nghĩa là log không được gộp

HTTP call

Một nhóm gồm 1 DioRequestLog và tối đa 1 DioResponseLog hoặc DioErrorLog

requestId

Id do TalkerDioLogger sinh cho mỗi lần gửi request; được chụp vào field của log ngay lúc ghi

requestIdKey

Tên key trong RequestOptions.extra dùng để lưu id; cấu hình được, mặc định talker-request-id

Pending

Call đã có request log nhưng chưa có response log hay error log

Kiến trúc tổng quan
Bản fork talker_dio_logger sinh id cho mỗi request. Bản fork talker_flutter chỉ biết gom log theo key, và không phụ thuộc dio. App nối 2 phần này lại qua DioGrouper.

Luồng xử lý đi qua 4 bước:

TalkerDioLogger (bản fork) nằm giữa interceptor auth và interceptor refresh token. Mỗi lần gửi request, nó sinh talker-request-id và chụp id vào từng log.

Log được ghi vào history dưới dạng log đơn, chưa gộp.

TalkerView hỏi DioGrouper key của từng log (chính là requestId) và cách vẽ từng nhóm.

Người dùng tap vào card để mở màn chi tiết; dữ liệu hiển thị đã được mask.

Yêu cầu chức năng: fork talker_flutter
Bản fork chỉ bổ sung khả năng gộp log ở tầng danh sách. Nó không phụ thuộc dio. Khi không truyền grouper, hành vi phải giống hệt upstream.

API mới

class TalkerLogGroup {
  final String key;
  final List<TalkerData> logs; // theo thứ tự thời gian
  TalkerData get first => logs.first;
  TalkerData get last => logs.last;
}

abstract class TalkerLogGrouper {
  const TalkerLogGrouper();
  /// null = log này không được gộp
  String? groupKeyOf(TalkerData data);
  /// null = dùng TalkerGroupCard mặc định
  Widget? buildGroup(BuildContext context, TalkerLogGroup group, TalkerScreenTheme theme) => null;
  /// Text cho copy/share; mặc định nối text của các log con
  String groupText(TalkerLogGroup group);
}
Yêu cầu

F1. Tham số. TalkerScreen và TalkerView nhận thêm TalkerLogGrouper? grouper, mặc định là null. Giữ nguyên itemsBuilder hiện có; nó vẫn áp dụng cho log đơn.

F2. Gom nhóm. Duyệt history theo thời gian và gom các log có cùng groupKey thành TalkerLogGroup. Nhóm nằm ở vị trí của log đầu tiên trong nhóm. Log có key null giữ nguyên là log đơn. Việc đảo thứ tự (isLogOrderReversed) áp dụng sau khi gom.

F3. Nhóm một phần tử. Nhóm chỉ có 1 log vẫn hiển thị bằng buildGroup, để call pending có giao diện nhất quán.

F4. Cập nhật tại chỗ. Khi có log mới thuộc một nhóm đã tồn tại (ví dụ response vừa về), item của nhóm đó rebuild tại vị trí cũ, không nhảy vị trí và không làm mất vị trí cuộn.

F5. Filter theo loại log. Một nhóm được giữ lại nếu có ít nhất 1 log con khớp filter, và khi đó hiển thị cả nhóm. Ví dụ: lọc "http-error" sẽ ra các call lỗi kèm request của chúng.

F6. Search. Áp dụng cùng quy tắc với F5, so khớp trên text của từng log con.

F7. Copy. Copy một item nhóm sẽ lấy groupText(group).

F8. Share và lưu file. Mỗi nhóm được xuất thành một khối text liền nhau, vẫn giữ thứ tự như trên màn hình.

F9. Thu gọn và mở rộng. TalkerGroupCard tuân theo setting expand/collapse chung của TalkerScreen.

F10. Card mặc định. TalkerGroupCard hiển thị title của log đầu, số lượng log con, và danh sách log con dạng thu gọn. Màu viền lấy theo log cuối qua TalkerScreenTheme.logColors.

F11. TalkerMonitor. Không thay đổi; vẫn đếm theo log đơn.

F12. Chịu lỗi. Nếu groupKeyOf hoặc buildGroup throw exception, log liên quan hiển thị như log đơn, màn hình không crash, và lỗi được ghi bằng debugPrint.

Yêu cầu chức năng: fork talker_dio_logger
TalkerDioLogger tự gán id cho mỗi lần gửi request và ghi id đó vào từng log, nên app không cần interceptor riêng để gán id.

Setting mới trong TalkerDioLoggerSettings

TalkerDioLoggerSettings(
  requestIdKey: 'talker-request-id', // mặc định
  requestIdBuilder: null,            // String Function(RequestOptions)?
  sendRequestIdHeader: false,        // mặc định không gửi lên server
  requestIdHeaderName: 'X-Request-Id',
)
Yêu cầu

D1. Sinh id. Mỗi lần onRequest chạy, logger sinh một id mới và ghi vào options.extra[requestIdKey]. Việc này vẫn xảy ra ngay cả khi options đã có id từ lần gửi trước (trường hợp retry). Id được sinh trước khi xét requestFilter, nhờ đó response vẫn mang id dù request log bị lọc bỏ.

D2. Cách sinh id mặc định. Định dạng <microsecondsSinceEpoch>-<counter>. counter là biến static dùng chung cho mọi instance logger, nên 2 Dio instance không bao giờ sinh trùng id. Không thêm dependency uuid.

D3. Id do app tự sinh. Nếu truyền requestIdBuilder, logger dùng kết quả của hàm này, ví dụ để tái dùng trace id mà app đã gắn. Hàm phải trả về giá trị khác nhau cho mỗi lần gửi. Logger cố ý không có chế độ "giữ id cũ nếu đã có", vì khi retry dùng lại RequestOptions, chế độ đó sẽ gộp nhầm các lần gọi.

D4. Chụp id vào log. DioRequestLog, DioResponseLog và DioErrorLog có thêm field final String? requestId, lấy giá trị ngay lúc log được tạo. Grouper chỉ đọc field này, không đọc lại options.extra. Nhờ vậy, khi extra bị ghi đè (retry, hoặc copyWith dùng chung map), các log cũ không bị đổi id theo. Field được thêm dưới dạng tham số named optional để không phá API cũ.

D5. Gửi id qua header (opt-in). Khi sendRequestIdHeader: true, logger thêm header requestIdHeaderName vào request để backend có thể đối chiếu log. Mặc định tắt, vì header mới có thể làm sai chữ ký request và gây CORS preflight trên web.

D6. Console. Định dạng log console giữ nguyên. Có thể bật printRequestId (mặc định false) để in id ở dòng tiêu đề của log.

Yêu cầu chức năng: phía app
Phía app chịu trách nhiệm biết cách ghép log của Dio và cách hiển thị một HTTP call. Toàn bộ code này nằm trong module debug của app, không nằm trong bản fork.

A1. Thứ tự interceptor. Khai báo cố định theo thứ tự: interceptor gắn auth → TalkerDioLogger → interceptor refresh token. Ghi chú lý do ngay tại chỗ khởi tạo Dio.

Logger đứng sau auth nên request log có đủ header, và lệnh cURL chạy lại được.

Logger đứng trước refresh nên vẫn ghi được lỗi 401. Nếu đứng sau, interceptor refresh sẽ resolve lỗi trước, logger không bao giờ thấy lỗi này, và request đầu tiên sẽ treo ở trạng thái pending mãi.

A2. DioGrouper.groupKeyOf. Trả về field requestId của DioRequestLog, DioResponseLog hoặc DioErrorLog. Với các loại log khác, hoặc log không có id, trả về null.

A3. Card HTTP call. Card hiển thị:

Badge method.

Path (tối đa 2 dòng) và host.

Status code. Nếu đang pending thì hiện "…"; nếu lỗi mà không có response thì hiện "ERR".

Duration tính bằng ms, bằng last.time - first.time.

A4. Màu theo trạng thái. Pending: xám. 2xx: xanh lá. 3xx: xanh dương. 4xx: cam. 5xx và lỗi mạng: đỏ. Dùng token màu của vetc-dls nếu có.

A5. Nhãn bất thường. Có 2 nhãn:

"Không phản hồi": call pending lâu hơn receiveTimeout + 5 giây. Nếu không đặt timeout thì lấy ngưỡng 60 giây.

"Thiếu request": nhóm chỉ có response hoặc error. Xảy ra khi request đã bị đẩy ra khỏi history, hoặc bị requestFilter lọc bỏ.

A6. Màn chi tiết. Tap vào card sẽ mở HttpCallDetailScreen, gồm 3 tab:

Request: requestId, method, URL đầy đủ, query params, headers, body dạng JSON được format.

Response: status, duration, headers, body. Nếu lỗi thì hiện thêm DioExceptionType, message, và body nếu có.

cURL: lệnh curl đầy đủ để chạy lại request.

A7. Thao tác trong màn chi tiết. Text cho phép chọn (SelectableText), mỗi tab có nút copy. Body lớn hơn 100 KB sẽ bị cắt, kèm nút "Xem toàn bộ".

A8. groupText. Xuất một khối text theo mẫu: dòng đầu [HTTP] GET /path → 200 (123 ms) #<requestId>, sau đó là phần Request và Response. Toàn bộ text đã được mask.

A9. Che dữ liệu nhạy cảm. Thay giá trị bằng *** cho:

Header: authorization, cookie, x-api-key, …

Field trong body: mật khẩu, OTP, PIN, số giấy tờ tùy thân trong luồng KYC, số thẻ, …

Mask áp dụng ở mọi nơi: card, màn chi tiết, copy, share, cURL. Mask theo tên key ở mọi cấp lồng của JSON. Danh sách cấu hình qua HttpLogMaskConfig.

A10. Bật/tắt. Chỉ truyền grouper khi flag enableHttpGrouping bật. Flag mặc định bật ở dev và staging.

Yêu cầu phi chức năng
Mã

Nhóm

Yêu cầu

NF1

Hiệu năng

Gom nhóm độ phức tạp O(n) mỗi lần rebuild. Với 1.000 log, thời gian gom dưới 4 ms trên máy Android tầm trung đời 2021

NF2

Hiệu năng

Danh sách 1.000 log cuộn ở 60 fps. Format JSON và mask body chỉ chạy khi mở chi tiết hoặc copy/share, không chạy khi render card

NF3

Hiệu năng

Sinh id không làm tăng đáng kể thời gian của một request: dưới 0,1 ms mỗi request

NF4

Tương thích

Khi không dùng tính năng mới (không truyền grouper, không bật header), cả 2 bản fork pass toàn bộ test của upstream 5.1.20 mà không phải sửa test

NF5

Tương thích

API công khai của cả 2 package giữ nguyên; chỉ được thêm tham số và field optional

NF6

Phụ thuộc

Không thêm dependency mới vào pubspec.yaml của cả 2 package

NF7

Bảo mật

Dữ liệu chưa mask không bao giờ xuất hiện khi copy, share hay lưu file (xem A9)

NF8

Bảo mật

Build production không chứa module debug và TalkerScreen; xác minh bằng kiểm tra kích thước và symbol của bản release

NF9

Kiểm thử

Có unit test cho sinh id (D1–D4), gom nhóm, filter và search; widget test cho TalkerGroupCard và card HTTP. Coverage code mới từ 90% trở lên

Quản lý fork & phát hành
Fork được quản lý như một lớp patch mỏng trên upstream, với mục tiêu dài hạn là gộp ngược vào repo gốc.

Repo và nhánh. Fork Frezyx/talker (monorepo chứa cả 2 package) về GitHub của tổ chức. Tạo nhánh vetc/grouping từ tag upstream v5.1.20.

Tổ chức code. Code mới đặt trong file riêng; file gốc chỉ sửa ở các điểm nối. Mục tiêu diff trong file gốc: dưới 150 dòng với talker_flutter (constructor, bước tạo item, filter, copy/share) và dưới 80 dòng với talker_dio_logger (interceptor, settings, 3 class log).

Tag phát hành. Một tag chung cho cả monorepo, theo mẫu <upstream-version>-vetc.<n>, ví dụ v5.1.20-vetc.1. Hai package luôn lấy cùng một tag để dùng chung một phiên bản talker core.

Khai báo dependency trong app. Override cả 2 package:

dependency_overrides:
  talker_flutter:
    git:
      url: https://github.com/<org>/talker.git
      path: packages/talker_flutter
      ref: v5.1.20-vetc.1
  talker_dio_logger:
    git:
      url: https://github.com/<org>/talker.git
      path: packages/talker_dio_logger
      ref: v5.1.20-vetc.1
Nâng version. Mỗi khi upstream ra bản mới: rebase vetc/grouping lên tag mới, chạy toàn bộ test (NF4, NF9) cho cả 2 package, rồi đặt tag -vetc.1 mới.

Gửi PR lên upstream. Chia thành 2 PR riêng:

Request id cho talker_dio_logger (D1–D6). PR này nhỏ và dễ được merge, nên gửi trước.

Grouping cho talker_flutter (F1–F12), gửi sau 2 sprint chạy ổn định.

PR nào được merge thì bỏ override của package tương ứng.

Tiêu chí nghiệm thu
Tính năng được nghiệm thu khi QA chạy đạt toàn bộ các kịch bản dưới đây trên bản staging, cả Android và iOS.


Gọi 1 API thành công: có 1 item, status 2xx, màu xanh lá, kèm duration.


Gọi 1 API chậm (giả lập trễ 5 giây): item hiện pending, rồi chuyển sang kết quả ngay tại vị trí cũ (F4).


Gọi 10 API song song: đúng 10 item, mỗi item khớp đúng response của nó (đối chiếu path và body).


Hai Dio instance cùng gọi API song song: không có 2 call nào trùng requestId (D2).


API trả 4xx, 5xx, hoặc mất mạng: có 1 item màu cam hoặc đỏ, tab Response hiện loại lỗi.


Refresh token rồi gọi lại bằng dio.fetch(err.requestOptions) (dùng lại cùng object): có 2 item riêng, lần 401 ở trạng thái lỗi và lần gọi lại ở trạng thái thành công; không item nào treo pending (D1, D4, A1).


Thử nghiệm đặt logger sau interceptor refresh: request đầu hiện nhãn "Không phản hồi" sau ngưỡng timeout (A5).


requestFilter lọc bỏ 1 request: response của request đó vẫn hiện card với nhãn "Thiếu request" (D1, A5).


Truyền requestIdBuilder: tab Request và text share hiển thị đúng id do app sinh (D3).


Bật sendRequestIdHeader: header có trên request khi xem qua proxy. Khi tắt, request không có header này (D5).


Filter "http-error": chỉ hiện các call lỗi, mỗi call kèm đủ request. Search theo path: tìm đúng call.


Share log: mỗi call là 1 khối text liền nhau, không chứa token, OTP, PIN hay số giấy tờ.


Copy lệnh cURL, chạy lại trên terminal (sau khi điền token thật): kết quả giống trên app.


Tắt enableHttpGrouping: màn log hiển thị giống hệt upstream.


Bản release không chứa TalkerScreen và module debug (NF8).

Rủi ro & câu hỏi mở
Rủi ro

Ảnh hưởng

Cách xử lý

Retry dùng lại cùng RequestOptions, hoặc copyWith dùng chung map extra

Ghi đè id làm log cũ đổi theo, dẫn đến gộp nhầm 2 lần gọi

Chụp id vào field của log ngay lúc ghi (D4); không có chế độ giữ id cũ (D3)

Logger đặt sau interceptor refresh token

Lỗi 401 không được ghi; request đầu treo pending mãi

Cố định thứ tự interceptor (A1) và ghi chú tại code; nhãn "Không phản hồi" (A5) làm lỗi này dễ phát hiện

requestIdBuilder trả cùng một id cho mọi lần retry (ví dụ trace id theo từng nghiệp vụ)

Các lần retry bị gộp vào một nhóm

Ghi rõ trong doc của setting; app ghép thêm hậu tố cho mỗi lần gửi

Hai bản fork lệch phiên bản talker core

Lỗi resolve dependency hoặc hành vi không khớp

Một tag chung cho cả monorepo; override cả 2 package cùng một ref

Upstream refactor interceptor hoặc TalkerView

Rebase bị conflict, chậm nâng version

Giữ diff nhỏ; gửi PR request id sớm để giảm phần phải tự duy trì

Bật gửi header id cho API có ký request

Request bị server từ chối

Mặc định tắt (D5); chỉ bật sau khi backend xác nhận

Request bị đẩy ra khỏi maxHistoryItems trong khi response vẫn còn

Nhóm thiếu phần request

Nhãn "Thiếu request" (A5); cân nhắc tăng maxHistoryItems

Bỏ sót field nhạy cảm khi mask

Lộ dữ liệu khi share log

Review danh sách mask cùng team bảo mật; mask theo tên key ở mọi cấp lồng của JSON (A9)

Câu hỏi mở


Có cần gom nhóm cả log console không, hay chỉ cần in id qua printRequestId?


Danh sách đầy đủ các header và field cần mask là gì? Cần team bảo mật xác nhận.


Ngưỡng hiệu năng NF1–NF3 và ngưỡng nhãn "Không phản hồi" (timeout + 5 giây, hoặc 60 giây) đã hợp lý chưa?


Backend có muốn nhận header request id không? Nếu có thì dùng tên header nào?


App đã có trace id riêng chưa? Nếu có, có nên lấy nó qua requestIdBuilder không?


Có mở rộng cách gộp này cho bridge call của WebView MiniApp ở đợt sau không?

