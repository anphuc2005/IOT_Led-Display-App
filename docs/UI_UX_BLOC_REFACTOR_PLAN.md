# Smart LED Control — UI/UX & BLoC Refactor Plan

## 1. Mục tiêu

- Xây dựng giao diện điều khiển nhà thông minh hiện đại, nhất quán và dễ dùng bằng một tay.
- Áp dụng design system xuyên suốt thay vì hardcode màu, kích thước và style theo từng màn.
- Dùng `Bloc<Event, State>` thuần cho toàn bộ trạng thái ứng dụng; không dùng Cubit, Provider hoặc ChangeNotifier.
- Không dùng `setState` cho navigation, form, loading, chat, MQTT, LED và sensor state.
- Hoàn thiện đầy đủ loading, success, error, disconnected, empty, stale-data và disabled state.
- Đảm bảo responsive, accessibility, testability và không còn lỗi encoding tiếng Việt.

> BLoC vẫn bắt buộc có lớp `State`. Quy ước “không dùng state” trong kế hoạch này được hiểu là không quản lý trạng thái bằng `setState` hoặc thư viện state management khác.

## 2. Design system được chọn

Kết quả UI/UX Pro Max phù hợp nhất là `Real-Time / Operations Dashboard`, density 7/10, variance 5/10 và motion 3/10.

### Visual direction

- Phong cách: dark smart-home dashboard, glass surface nhẹ, không lạm dụng blur hoặc gradient.
- Màu nền: `#0F172A`.
- Surface chính: `#1E293B`.
- Card: `#1B2336`.
- Border: `#475569`.
- Text chính: `#F8FAFC`.
- Text phụ: `#94A3B8` nhưng phải kiểm tra contrast tối thiểu 4.5:1.
- Accent/CTA: `#22C55E` cho kết nối, bật và thành công.
- Info/control accent: cyan/blue dùng cho slider, selection và dữ liệu.
- Warning: amber; error/destructive: `#EF4444`.
- Font: Plus Jakarta Sans, fallback về system sans-serif khi font chưa tải được.

### Tokens bắt buộc

- Spacing: 4, 8, 12, 16, 24, 32.
- Radius: 12 cho field/button, 16 cho card, 24 cho panel nổi.
- Icon: 20, 24, 32; dùng duy nhất Material Symbols/Icons đồng nhất.
- Touch target: tối thiểu 48×48dp.
- Motion: 120ms pressed, 200ms state change, 300ms page/content transition.
- Elevation: tối đa 3 cấp, ưu tiên border/surface thay vì shadow mạnh.

## 3. Kiến trúc BLoC mục tiêu

```text
AppBloc
├── khởi tạo app
├── tải cấu hình đã lưu
└── điều phối trạng thái ready/failure

NavigationBloc
└── tab hiện tại + back behavior

MqttBloc
├── connect/disconnect/reconnect
├── config changed
├── topic subscription
└── connected/connecting/disconnected/failure

LedBloc
├── power/color/brightness/effect
├── auto mode
├── command acknowledgement/failure
└── optimistic update + rollback khi gửi lỗi

SensorBloc
├── light/motion stream
├── history buffer
├── live/paused/stale state
└── auto-brightness policy

ChatBloc
├── message draft/send/retry
├── Gemini processing
└── command execution result

SettingsBloc
├── load/edit/validate/save
└── reconnect result
```

### Quy tắc triển khai

- UI chỉ `add(Event)` và render từ state qua `BlocBuilder`, `BlocSelector`, `BlocListener`.
- Không tạo method facade như `led.togglePower()` trên Bloc.
- Mọi dữ liệu từ MQTT stream phải trở thành event nội bộ trước khi emit state.
- Service/repository không kế thừa `ChangeNotifier`.
- State dùng value equality (`Equatable` hoặc sealed immutable state).
- Event tốc độ cao như brightness slider được debounce/throttle trước khi publish MQTT.
- Không nuốt exception; chuyển thành typed failure và state có thông báo cho người dùng.
- Bảo đảm subscription được tạo sau khi config đã load và được thay mới khi topic prefix đổi.

## 4. Information architecture và màn hình

Bottom navigation giữ tối đa 5 mục:

1. Tổng quan
2. Màu sắc
3. Hiệu ứng
4. Trợ lý AI
5. Cảm biến

Cài đặt mở từ nút header và có back behavior chuẩn. Trạng thái tab do `NavigationBloc` quản lý và giữ nguyên state/scroll khi đổi tab.

## 5. Kế hoạch theo màn hình

### 5.1 Splash / App initialization

- Logo tối giản, không pulse vô hạn.
- Hiển thị tiến trình: tải cấu hình → khởi tạo dịch vụ → kết nối MQTT.
- Timeout rõ ràng; cho phép “Thử lại” hoặc “Tiếp tục ngoại tuyến”.
- Tôn trọng reduced motion.

### 5.2 Tổng quan

- Header: tên thiết bị, trạng thái kết nối bằng icon + text + màu, thời điểm cập nhật cuối.
- Hero control: bật/tắt LED, màu hiện tại, brightness và effect trong một card chính.
- Quick controls thực sự điều hướng được; loại bỏ callback rỗng.
- Slider chỉ publish theo debounce, vẫn cập nhật preview tức thì.
- Sensor summary gồm lux, motion và freshness.
- Khi offline: control disabled có giải thích và CTA kết nối lại.
- Bố cục 1 cột trên phone, 2 cột trên tablet/landscape bằng `LayoutBuilder`.

### 5.3 Màu sắc

- Color preview lớn nhưng không chiếm quá nhiều chiều cao.
- Color wheel + RGB có cùng draft state trong `ColorBloc` hoặc nhánh event của `LedBloc`.
- Nút “Áp dụng” có loading/success/error state.
- Preset màu dùng grid responsive, mỗi màu có tên và selected indicator ngoài màu sắc.
- Giá trị RGB hỗ trợ text scaling, không dùng font 10px.

### 5.4 Hiệu ứng

- Card hiệu ứng dùng icon vector, tên và mô tả ngắn.
- Selected state thể hiện bằng border + check + text, không chỉ đổi màu.
- Speed control hiển thị nhãn có nghĩa: Nhanh / Vừa / Chậm và số ms.
- Preview và apply tách rõ nếu firmware không hỗ trợ preview realtime.
- Khi LED tắt, giải thích hiệu ứng sẽ tự bật LED hoặc yêu cầu xác nhận theo quyết định sản phẩm.

### 5.5 Trợ lý AI

- `ChatBloc` thay toàn bộ `setState`.
- Message list có retry, sending, sent, failed.
- Composer giữ an toàn với bàn phím và bottom inset.
- Quick prompts dùng chip/button có ripple và semantics.
- Kết quả lệnh hiển thị command summary, success/failure; không ghi “đã thực thi” trước khi có kết quả.
- Không có API key: empty state dẫn thẳng tới Cài đặt.

### 5.6 Cảm biến

- Current-value cards cho lux và motion.
- Streaming area chart cho lịch sử lux; buffer giới hạn 60–300 điểm.
- Có Pause/Resume, reset range và “cập nhật lần cuối”.
- Dữ liệu stale phải có trạng thái riêng sau một ngưỡng thời gian.
- Chart không dùng màu làm tín hiệu duy nhất; có marker/label và phần tóm tắt dạng text.
- Khi chưa có dữ liệu: skeleton ngắn rồi empty/error state.

### 5.7 Cài đặt

- Dùng `Form` + validation theo field khi blur.
- Nhóm: MQTT, Gemini, LED hardware và About.
- Broker/port/topic prefix có helper text và lỗi cụ thể.
- Nút lưu disable khi không có thay đổi hoặc đang submit.
- Luồng submit: validating → saving → reconnecting → success/failure.
- API key và password chuyển sang secure storage; vẫn cho phép paste/password manager.
- Link lấy Gemini key phải hoạt động hoặc bỏ affordance click giả.

## 6. Component hóa

Tạo các component dùng chung:

- `AppScaffold`
- `AppTopBar`
- `ConnectionStatusBadge`
- `SmartCard`
- `SectionHeader`
- `PrimaryButton`, `SecondaryButton`, `IconActionButton`
- `StatusBanner`
- `LoadingPanel`, `EmptyPanel`, `ErrorPanel`
- `MetricCard`
- `LedColorSwatch`
- `ResponsiveContent`

Mỗi component dùng theme token, có semantics, trạng thái pressed/disabled/loading và touch target đạt chuẩn.

## 7. Công việc nền tảng cần làm trước UI

- Sửa toàn bộ mojibake tiếng Việt và chuẩn hóa file UTF-8.
- Xóa `ChangeNotifier` và mọi import Provider còn lại.
- Tách models khỏi Flutter UI type khi hợp lý; RGB nên là domain value thay vì `Color` trực tiếp.
- Chuẩn hóa MQTT command/response thành DTO có validation.
- Đưa API key sang secure storage.
- Bổ sung route/navigation có type và back behavior rõ.
- Thay API deprecated (`withOpacity`, `Color.red/green/blue`, `activeColor`).
- Xử lý lifecycle/reconnect và resubscribe đúng topic mới.

## 8. Responsive và accessibility

- Test tối thiểu: 360×640, 375×812, 412×915, tablet 768px và landscape.
- Dùng `LayoutBuilder`; không cố định chiều rộng màn hình.
- Text scale: 1.0, 1.3 và 2.0 không overflow hoặc mất chức năng.
- TalkBack/VoiceOver đọc đúng label, value, selected/toggled state.
- Icon-only button có tooltip và semantic label.
- Không dùng `GestureDetector` cho button nếu có thể dùng Material button/InkWell.
- Safe area đúng cho app bar, keyboard, bottom navigation và gesture bar.
- Motion không cần thiết bị vô hiệu khi accessibility reduce motion bật.

## 9. Kiểm thử

### Unit tests

- Mỗi Bloc: initial state, success, failure, retry và edge cases.
- MQTT mapper/parser với payload hợp lệ và lỗi.
- Auto brightness boundary: 50, 200, 500 lux.
- Gemini command parser và invalid command.

### Widget tests

- Mỗi màn có loading, data, empty, error, disconnected.
- Navigation và state preservation.
- Form validation và submit feedback.
- Text scaling và small-screen overflow.
- Semantics label cho control quan trọng.

### Integration tests

- App start → load config → connect MQTT.
- Toggle power → MQTT publish → UI acknowledgement.
- Đổi broker/topic → reconnect → resubscribe.
- AI command → LED command.
- Sensor stream → chart/history → pause/resume.

## 10. Các giai đoạn thực hiện

### Phase 0 — Baseline

- Chụp trạng thái hiện tại, chạy analyze/test và ghi nhận lỗi.
- Sửa encoding tiếng Việt.
- Chốt design tokens và acceptance checklist.

### Phase 1 — BLoC foundation

- AppBloc, NavigationBloc, MqttBloc.
- Repository interfaces và typed failures.
- Sửa thứ tự app initialization.
- Loại bỏ ChangeNotifier/Provider/setState dùng cho app state.

### Phase 2 — LED & sensors

- Chuẩn hóa LedBloc theo event-driven.
- Tách SensorBloc, debounce/throttle và stale data.
- Unit test đầy đủ.

### Phase 3 — Design system & shared components

- Theme tokens, light/dark color scheme, typography.
- Responsive shell và shared components.
- Accessibility primitives.

### Phase 4 — Screen rebuild

- Tổng quan → Màu sắc → Hiệu ứng → Cảm biến → AI → Cài đặt.
- Hoàn thiện từng màn trước khi chuyển màn tiếp theo.

### Phase 5 — Quality pass

- Widget/integration tests.
- Analyze không warning liên quan code dự án.
- Test small phone/tablet/landscape/text scaling.
- TalkBack/VoiceOver và reduced motion.
- Performance check sensor chart và MQTT event frequency.

## 11. Definition of Done

- Không còn Cubit, Provider, ChangeNotifier hoặc business state bằng `setState`.
- Không còn `emit` ngoài Bloc event handler.
- Không còn text lỗi encoding.
- Tất cả action nhìn thấy đều hoạt động; không còn callback rỗng.
- Mỗi async flow có loading, success và error feedback.
- `flutter analyze` không có error/warning từ code dự án.
- Unit, widget và integration tests quan trọng đều pass.
- UI không overflow ở các kích thước và text scale đã quy định.
- Touch target, contrast, semantics và safe area đạt checklist UI/UX Pro Max.
