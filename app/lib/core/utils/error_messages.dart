import '../api/api_exceptions.dart';

/// Chuyển đổi mã lỗi backend thành thông báo tiếng Việt thân thiện với người dùng.
String mapErrorMessage(dynamic error, {String? defaultMessage}) {
  if (error is ApiException) {
    if (error.isNetworkError) {
      return 'Không kết nối được máy chủ. Vui lòng kiểm tra kết nối mạng.';
    }

    final code = error.code.toUpperCase();
    switch (code) {
      case 'REFERRAL_DISABLED':
        return 'Chương trình giới thiệu hiện chưa mở.';
      case 'INVALID_CODE':
        return 'Mã giới thiệu không hợp lệ.';
      case 'OWN_CODE':
        return 'Bạn không thể nhập mã giới thiệu của chính mình.';
      case 'ALREADY_REDEEMED':
        return 'Bạn đã nhập mã giới thiệu rồi.';
      case 'TOO_LATE':
        return 'Chỉ có thể nhập mã trong 7 ngày đầu tạo tài khoản.';
      case 'CONFIG_CHANGED':
        return 'Cấu hình đã thay đổi. Hãy tải lại trang trước khi lưu.';
      case 'USER_NOT_FOUND':
        return 'Không tìm thấy tài khoản với email này.';
      case 'ONBOARDING_REQUIRED':
        return 'Bạn cần hoàn thành bảng khảo sát ban đầu trước khi tiếp tục.';
      case 'EXERCISE_CATALOG_EMPTY':
        return 'Máy chủ chưa có dữ liệu bài tập nên chưa lập được kế hoạch. Vui lòng thử lại sau.';
      case 'COACH_LIMIT':
        return 'Hôm nay bạn đã dùng hết lượt nhắn tin với Coach. Hãy quay lại vào ngày mai nhé!';
      case 'PHOTO_LIMIT_REACHED':
        return 'Đã đạt giới hạn nhận diện ảnh món ăn trong ngày.';
      case 'ALREADY_CHECKED_IN':
        return 'Bạn đã check-in cho ngày hôm nay rồi.';
      case 'ALREADY_PAIRED':
        return 'Bạn đã có bạn đồng hành (buddy) rồi.';
      case 'INVITE_NOT_FOUND':
        return 'Không tìm thấy mã mời hợp lệ hoặc mã không tồn tại.';
      case 'INVITE_EXPIRED':
        return 'Mã mời đã hết hạn sử dụng.';
      case 'INVITE_USED':
        return 'Mã mời này đã được người khác sử dụng.';
      case 'OWN_INVITE':
        return 'Bạn không thể tự ghép cặp với chính mã mời của mình.';
      case 'NO_BUDDY':
        return 'Bạn chưa ghép cặp với bạn đồng hành nào.';
      case 'NO_ACTIVE_PLAN':
        return 'Chưa có kế hoạch tập luyện nào đang hoạt động.';
      case 'NO_REVIEW':
        return 'Chưa có tổng kết tuần mới.';
      case 'ALREADY_NUDGED':
        return 'Hôm nay bạn đã gửi lời nhắc cho bạn đồng hành rồi.';
      case 'ALREADY_CHEERED':
        return 'Hôm nay bạn đã gửi lời cổ vũ cho bạn đồng hành rồi.';
      case 'BUDDY_DONE':
        return 'Bạn đồng hành đã hoàn thành buổi tập hôm nay rồi!';
      case 'BODY_AREA_REQUIRED':
        return 'Vui lòng chọn vị trí đau để điều chỉnh bài tập an toàn.';
      case 'SCHEDULED_DATE_REQUIRED':
        return 'Vui lòng chọn ngày tập mới.';
      case 'SESSION_NOT_FOUND':
        return 'Không tìm thấy thông tin buổi tập.';
      case 'SESSION_NOT_PLANNED':
        return 'Buổi này đã tập hoặc đã bỏ, không đổi được nữa.';
      case 'AI_UNAVAILABLE':
        return 'Trợ lý AI đang bận. Vui lòng thử lại sau giây lát.';
      case 'VALIDATION_ERROR':
        return 'Thông tin nhập vào chưa hợp lệ. Vui lòng kiểm tra lại.';
      case 'NOTHING_TO_UPDATE':
        return 'Bạn chưa thay đổi thông tin nào.';
      case 'INVALID_TIMEZONE':
        return 'Múi giờ không hợp lệ.';
      case 'DUPLICATE_WEEKDAY':
        return 'Không được chọn trùng thứ trong tuần.';
      case 'NETWORK_ERROR':
        return 'Không kết nối được máy chủ. Vui lòng kiểm tra kết nối mạng.';
      default:
        break;
    }

    if (error.statusCode != null) {
      switch (error.statusCode) {
        case 401:
          return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
        case 403:
          return 'Bạn không có quyền thực hiện thao tác này.';
        case 404:
          return 'Không tìm thấy dữ liệu yêu cầu.';
        case 429:
          return 'Hệ thống đang quá tải hoặc bạn đã vượt quá giới hạn yêu cầu.';
        case 500:
        case 502:
        case 503:
          return 'Hệ thống đang gặp sự cố. Vui lòng thử lại sau.';
        default:
          return defaultMessage ??
              'Có lỗi xảy ra (${error.statusCode}). Vui lòng thử lại.';
      }
    }

    return defaultMessage ??
        'Đã có lỗi xảy ra (${error.code}). Vui lòng thử lại.';
  }

  return defaultMessage ??
      (error?.toString() ?? 'Đã có lỗi xảy ra. Vui lòng thử lại.');
}
