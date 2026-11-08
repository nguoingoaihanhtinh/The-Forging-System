# Hướng dẫn chuẩn bị Flutter iOS trên Windows (chưa đăng ký Apple Developer)

> **Môi trường:** Windows 11, Flutter project hiện có, GitHub và Codemagic (máy build macOS cloud).  
> **Mục tiêu hiện tại:** kiểm tra iOS release build **không ký**.  
> **Mục tiêu sau phê duyệt:** Apple Developer Program → ký ứng dụng → TestFlight → App Store.

## 0. Phạm vi và giới hạn

- Không cần sở hữu Mac để chuẩn bị source và chạy build iOS trên Codemagic.
- Không thể chạy Xcode/iOS Simulator trực tiếp trên Windows.
- Build `--no-codesign` chỉ chứng minh project biên dịch được trên iOS; **không thể** upload bản build này lên TestFlight hoặc App Store.
- Apple Developer Program chưa cần đăng ký ở giai đoạn này. Codemagic có thể tính phí theo gói/hạn mức sử dụng.
- Hướng dẫn này là cấu hình khởi đầu; plugin native, Firebase, môi trường và phiên bản Flutter thực tế có thể cần điều chỉnh.

## 1. Kiểm tra môi trường Windows

Mở PowerShell tại thư mục gốc Flutter project:

```powershell
flutter --version
flutter doctor -v
flutter pub get
flutter analyze
flutter test
```

`flutter test` có thể báo chưa có test; nếu vậy hãy bổ sung test hoặc ghi nhận rõ. Việc `flutter doctor` báo thiếu Xcode trên Windows là bình thường.

Kiểm tra thư mục iOS:

```powershell
Test-Path .\ios
```

Nếu trả về `False`, chạy:

```powershell
flutter create --platforms=ios .
```

**Không chạy lại lệnh tạo platform tùy tiện nếu dự án đã tùy chỉnh native iOS.** Commit hoặc backup trước khi sửa cấu hình.

## 2. Chuẩn bị cấu hình ứng dụng

### 2.1 Version

Trong `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

`1.0.0` là version hiển thị, `1` là build number. Khi upload các build tiếp theo, tăng build number.

### 2.2 Bundle Identifier dự kiến

Chọn một ID ổn định, ví dụ `com.company.product`. Đảm bảo iOS target `Runner` sử dụng ID này; **Android `applicationId` không tự cập nhật Bundle ID iOS**. Khi chưa có Mac, có thể kiểm tra/chỉnh `PRODUCT_BUNDLE_IDENTIFIER` trong `ios/Runner.xcodeproj/project.pbxproj` (nên review thay đổi và kiểm tra cả cấu hình Debug/Profile/Release). Sau khi có quyền Apple Developer, đăng ký **đúng ID này**.

### 2.3 Cấu hình native

- Tên app: `ios/Runner/Info.plist` (`CFBundleDisplayName`), hoặc qua Xcode khi có môi trường macOS.
- App icon: chuẩn bị icon 1024 × 1024, cập nhật assets iOS phù hợp.
- Quyền camera, ảnh, microphone, location: bổ sung các `NS...UsageDescription` cần thiết trong `Info.plist` nếu plugin sử dụng.
- Nếu dùng Firebase/Google Sign-In/Push Notifications/Universal Links: cần cấu hình riêng cho iOS, Bundle ID và capability tương ứng.
- Kiểm tra API base URL, HTTPS, secrets, quyền riêng tư và cấu hình production. Không commit secret hoặc private key.

## 3. Đẩy source lên GitHub

```powershell
git status
git add .
git commit -m "Prepare Flutter iOS unsigned build"
git push origin main
```

Thay `main` bằng branch thực tế. Trước khi push, kiểm tra `.gitignore` và `git status` để không đẩy `.env`, `.p8`, `.p12`, `.mobileprovision` hoặc thông tin bí mật.

## 4. Tạo workflow Codemagic (không cần Apple Developer)

Tạo file **`codemagic.yaml`** tại root repository:

```yaml
workflows:
  ios-unsigned:
    name: iOS unsigned release validation
    max_build_duration: 60
    instance_type: mac_mini_m2
    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
    scripts:
      - name: Install Flutter packages
        script: flutter pub get
      - name: Analyze Dart code
        script: flutter analyze
      - name: Build iOS without signing
        script: flutter build ios --release --no-codesign
    artifacts:
      - build/ios/iphoneos/*.app
      - /tmp/xcodebuild_logs/*.log
```

**Lưu ý cấu hình:** `flutter: stable` và `xcode: latest` tiện để bắt đầu nhưng có thể gây thay đổi phiên bản ngoài ý muốn. Sau khi build ổn định, hãy ghim Flutter/Xcode version tương thích với dự án. `mac_mini_m2` phụ thuộc loại máy/gói Codemagic đang hỗ trợ; nếu workflow bị từ chối do instance type, chọn loại máy macOS có sẵn trong tài khoản rồi cập nhật YAML. `flutter analyze` có thể thất bại do lint tồn tại sẵn; xử lý lint hoặc tách bước kiểm tra, không tự động bỏ qua lỗi build.

Commit và push:

```powershell
git add codemagic.yaml
git commit -m "Add Codemagic unsigned iOS workflow"
git push origin main
```

## 5. Chạy trên Codemagic

1. Truy cập https://codemagic.io/ và đăng nhập.
2. Kết nối GitHub, chọn repository Flutter.
3. Chọn cấu hình **Codemagic YAML** (`codemagic.yaml`).
4. Chọn workflow `ios-unsigned`, branch phù hợp.
5. Chọn **Start new build**.
6. Đọc log theo thứ tự: `pub get` → `analyze` → `Build iOS without signing`.
7. Nếu build thành công, lưu link build/log/artifact để báo cáo.

**Kết quả mong đợi:** `flutter build ios --release --no-codesign` thành công và tạo `.app` chưa ký. File này **không phải** IPA phân phối và không thể gửi lên TestFlight.

### Lỗi thường gặp

| Lỗi | Kiểm tra |
|---|---|
| CocoaPods / plugin native lỗi | Phiên bản plugin, iOS deployment target, Xcode, Podfile |
| iOS deployment target quá thấp | Yêu cầu iOS tối thiểu của plugin và Podfile/project |
| Firebase config thiếu | `GoogleService-Info.plist`, Bundle ID, plugin iOS |
| Flutter/Dart SDK không khớp | Ghim phiên bản Flutter tương thích với `pubspec.yaml` |
| Build trên Android chạy nhưng iOS lỗi | Plugin chỉ hỗ trợ Android, quyền iOS, mã native, API iOS |
| Codemagic không có instance đã chọn | Chọn instance macOS khả dụng trong tài khoản |

## 6. Checklist hoàn thành trước khi được duyệt chi phí

- [ ] Flutter project có thư mục `ios/`.
- [ ] `flutter pub get` thành công.
- [ ] Đã rà soát `flutter analyze` và test.
- [ ] Đã chọn Bundle Identifier dự kiến.
- [ ] Đã cấu hình tên app, icon, permissions.
- [ ] Đã kiểm tra plugin iOS, Firebase và API production.
- [ ] Source đã push lên GitHub an toàn.
- [ ] Codemagic chạy thành công workflow `ios-unsigned`.
- [ ] Đã lưu build log và ghi nhận lỗi/cảnh báo còn lại.
- [ ] Đã chuẩn bị bản nháp App Store description, screenshots, Privacy Policy URL, Support URL và tài khoản demo (nếu cần).

## 7. Chỉ thực hiện sau khi được đồng ý Apple Developer Program

1. Quyết định đăng ký **cá nhân hay tổ chức**; xác minh tư cách chủ sở hữu app.
2. Đăng ký/kích hoạt Apple Developer Program (phí tiêu chuẩn thường 99 USD/năm, tùy khu vực).
3. Tạo App ID với Bundle ID đã chọn trong Apple Developer.
4. Tạo app trong App Store Connect.
5. Tạo App Store Connect API Key với quyền phù hợp; giữ kín file `.p8`.
6. Kết nối Apple Developer Portal/App Store Connect với Codemagic.
7. Cấu hình **automatic iOS code signing**, distribution provisioning profile và publishing.
8. Chạy signed iOS release build, tạo IPA và upload lên App Store Connect.
9. Kiểm thử TestFlight (internal trước, external nếu cần).
10. Hoàn tất metadata, App Privacy, screenshots, review credentials; gửi App Review.

**Không thêm signing key hoặc upload TestFlight vào workflow `ios-unsigned` hiện tại.** Nên tạo workflow `ios-release` riêng khi đã có membership để giữ ranh giới rõ ràng.

## 8. Tài liệu chính thức

- Flutter iOS deployment: https://docs.flutter.dev/deployment/ios
- Codemagic YAML quick start: https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/
- Codemagic iOS code signing: https://docs.codemagic.io/flutter-code-signing/ios-code-signing/
- Codemagic App Store publishing: https://docs.codemagic.io/flutter-publishing/publishing-to-app-store/
- Apple Developer enrollment: https://developer.apple.com/programs/enroll/

---

**Mốc bàn giao giai đoạn 1:** Có bằng chứng build iOS unsigned thành công trên Codemagic, danh sách vấn đề còn tồn tại và bộ thông tin chuẩn bị phát hành. Không tuyên bố app đã sẵn sàng TestFlight nếu chưa ký và kiểm thử bản phân phối.
