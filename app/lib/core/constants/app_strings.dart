class AppStrings {
  AppStrings._();

  // General
  static const String appName = 'LevelUp';
  static const String btnContinue = 'Tiếp tục';
  static const String btnBack = 'Quay lại';
  static const String alreadyHaveAccount = 'Đã có tài khoản? ';
  static const String logIn = 'Đăng nhập';

  // 1/7 - Main / Goal
  static const String goalStep = '1/7';
  static const String goalTitle = 'Chào bạn! Mục tiêu chính của bạn là gì?';
  static const String goalSubtitle = 'Chọn 1 mục tiêu, bạn có thể đổi sau.';
  static const String goalLoseFatTitle = 'Giảm mỡ';
  static const String goalLoseFatDesc = 'Giảm cân, săn chắc hơn';
  static const String goalBuildMuscleTitle = 'Tăng cơ';
  static const String goalBuildMuscleDesc = 'Tăng sức mạnh và cơ bắp';
  static const String goalGetHealthierTitle = 'Khỏe hơn';
  static const String goalGetHealthierDesc = 'Nhiều năng lượng, ngủ ngon hơn';
  static const String goalMaintainTitle = 'Giữ dáng';
  static const String goalMaintainDesc = 'Duy trì vóc dáng hiện tại';

  // 2/7 - Body
  static const String bodyStep = '2/7';
  static const String bodyTitle = 'Cho coach biết một chút về bạn';
  static const String bodySubtitle = 'Dùng để tính lượng calo và mức tập phù hợp. Chỉ bạn thấy.';
  static const String genderLabel = 'Giới tính';
  static const String genderMale = 'Nam';
  static const String genderFemale = 'Nữ';
  static const String genderOther = 'Khác';
  static const String birthYearLabel = 'Năm sinh';
  static const String heightLabel = 'Chiều cao (cm)';
  static const String weightLabel = 'Cân nặng (kg)';
  static const String goalWeightLabel = 'Mục tiêu (kg)';
  static String bodyGoalNotice(int goalKg, int weeks) =>
      'Mục tiêu ${goalKg}kg: coach đề xuất giảm khoảng 0.5kg mỗi tuần, tức khoảng $weeks tuần. Tốc độ này an toàn và dễ giữ.';

  // 3/7 - Training
  static const String trainingStep = '3/7';
  static const String trainingTitle = 'Bạn tập luyện thế nào?';
  static const String expLabel = 'Kinh nghiệm';
  static const String expBeginner = 'Mới bắt đầu';
  static const String expIntermediate = 'Đã tập một thời gian';
  static const String expRegular = 'Tập đều đặn';
  static const String locationLabel = 'Bạn tập ở đâu?';
  static const String locationHome = 'Ở nhà';
  static const String locationGym = 'Phòng gym';
  static const String locationOutdoor = 'Ngoài trời';
  static const String equipmentLabel = 'Dụng cụ có sẵn ';
  static const String equipmentMultipleHint = '(chọn nhiều)';
  static const String equipmentNone = 'Không có';
  static const String equipmentDumbbell = 'Tạ đơn';
  static const String equipmentMat = 'Thảm';
  static const String equipmentBand = 'Dây kháng lực';
  static const String equipmentPullupBar = 'Xà đơn';
  static const String injuryLabel = 'Có chỗ nào đau hoặc chấn thương không?';
  static const String injuryNone = 'Không';
  static const String injuryLowerBack = 'Lưng dưới';
  static const String injuryKnee = 'Gối';
  static const String injuryShoulder = 'Vai';
  static const String injuryOther = 'Khác';
  static const String injuryNote = 'Coach sẽ tránh các động tác gây áp lực lên vùng này.';

  // 4/7 - Schedule
  static const String scheduleStep = '4/7';
  static const String scheduleTitle = 'Khi nào bạn rảnh để tập?';
  static const String daysOfWeekLabel = 'Ngày trong tuần';
  static const String weekdayMon = 'T2';
  static const String weekdayTue = 'T3';
  static const String weekdayWed = 'T4';
  static const String weekdayThu = 'T5';
  static const String weekdayFri = 'T6';
  static const String weekdaySat = 'T7';
  static const String weekdaySun = 'CN';
  static const String timeSlotLabel = 'Khung giờ thường tập';
  static const String slotEarlyMorningTitle = 'Sáng sớm';
  static const String slotEarlyMorningTime = '5:00–8:00';
  static const String slotNoonTitle = 'Buổi trưa';
  static const String slotNoonTime = '11:00–13:00';
  static const String slotEveningTitle = 'Chiều tối';
  static const String slotEveningTime = '18:00–20:00';
  static const String slotLateEveningTitle = 'Tối muộn';
  static const String slotLateEveningTime = '20:00–22:00';
  static const String durationLabel = 'Mỗi buổi bạn có bao lâu?';
  static const String duration1015 = "10–15'";
  static const String duration20 = "20'";
  static const String duration30 = "30'";
  static const String duration45Plus = "45'+";
  static const String scheduleTip = 'Tuần đầu coach đề xuất 3 buổi, mỗi buổi 10–15 phút. Bắt đầu nhẹ để giữ được lâu, coach sẽ tăng dần.';

  // 5/7 - Why
  static const String whyStep = '5/7';
  static const String whyTitle = 'Vì sao bạn muốn thay đổi?';
  static const String whySubtitle = 'Coach sẽ nhắc lại điều này vào những lúc bạn thấy nản.';
  static const String reasonMirror = 'Tự tin hơn khi soi gương';
  static const String reasonOldClothes = 'Mặc vừa đồ cũ';
  static const String reasonPlayWithKids = 'Khỏe để chơi với con';
  static const String reasonDoctorAdvice = 'Bác sĩ khuyên';
  static const String reasonLessFatigue = 'Bớt mệt mỏi';
  static const String reasonUpcomingEvent = 'Chuẩn bị cho một sự kiện';
  static const String whyCustomLabel = 'Viết thêm bằng lời của bạn ';
  static const String whyCustomOptional = '(không bắt buộc)';
  static const String whyCustomDefault = 'Muốn mặc lại chiếc sơ mi cũ trước Tết';
  static const String coachExamplePrefix = 'Ví dụ coach sẽ nói: ';
  static const String coachExampleQuote = '"Nhớ chiếc sơ mi trước Tết không? Còn 12 tuần, hôm nay 10 phút thôi."';

  // 6/7 - Coach
  static const String coachStep = '6/7';
  static const String coachTitle = 'Bạn muốn coach nói chuyện thế nào?';
  static const String coachSubtitle = 'Đổi bất cứ lúc nào trong Cài đặt.';
  static const String coachStrictTitle = 'Nghiêm khắc';
  static const String coachStrictQuote = '"2 buổi rồi đấy. Không cần 30 phút, 10 phút thôi. Bắt đầu chứ?"';
  static const String coachSupportiveTitle = 'Động viên';
  static const String coachSupportiveQuote = '"Mấy hôm nay chắc bạn bận lắm. Công sức tuần trước vẫn còn nguyên, mình làm 10 phút nhẹ nhàng nhé?"';
  static const String coachFunnyTitle = 'Hài hước';
  static const String coachFunnyQuote = '"Tạ nhà bạn gửi lời hỏi thăm, nó bảo nhớ bạn. 10 phút thôi, hứa không đau lắm."';
  static const String coachSelectedBadge = 'Đang chọn';
  static const String btnCreateMyPlan = 'Tạo kế hoạch của tôi';

  // 7/7 - Plan
  static const String planStep = '7/7';
  static const String planTitle = 'Kế hoạch tuần 1 của bạn';
  static const String planSubtitle = '3 buổi ngắn để làm quen. Coach sẽ tăng dần theo sức của bạn.';
  static const String planInjuryNotice = 'Đã bỏ các động tác gây áp lực lên lưng dưới';
  static const String buddyInviteTitle = 'Tập cùng một người bạn?';
  static const String buddyInviteSubtitle = 'Hai người thấy tiến độ của nhau thường giữ thói quen lâu hơn.';
  static const String btnInviteBuddy = 'Mời buddy';
  static const String btnLater = 'Để sau';

  // OB-Notify
  static const String btnSkip = 'Bỏ qua';
  static const String notifyMockTitle1 = 'Coach · 18:00';
  static const String notifyMockBody1 = 'Còn 30 phút nữa tới buổi Toàn thân 12 phút. Tuần này bạn đã xong 1/3 buổi!';
  static const String notifyMockTitle2 = 'Coach · 7:30';
  static const String notifyMockBody2 = 'Chào buổi sáng! Hôm nay bạn thấy thế nào?';
  static const String notifyTitle = 'Để coach nhắc bạn đúng lúc';
  static const String notifySubtitle = 'Coach chỉ nhắc khi có việc thật sự cần, không spam.';
  static const String notifyPoint1 = 'Nhắc 30 phút trước giờ tập bạn chọn';
  static const String notifyPoint2 = 'Tối đa 2 thông báo mỗi ngày';
  static const String notifyPoint3 = 'Không làm phiền từ 22:00 đến 7:00';
  static const String btnEnableNotification = 'Bật thông báo';

  // OB-Start
  static const String startReady = 'MỌI THỨ ĐÃ SẴN SÀNG';
  static const String startTitle = 'Thử ngay buổi làm quen 5 phút nhé, Minh?';
  static const String startSubtitle = 'Không cần dụng cụ, không cần thay đồ. Coach sẽ xem bạn thấy thế nào để chỉnh kế hoạch.';
  static const String startWorkoutImagePlaceholder = '[Ảnh minh họa buổi tập]';
  static const String startEx1Title = 'Bật nhảy tại chỗ';
  static const String startEx1Duration = '60 giây';
  static const String startEx2Title = 'Squat không tạ';
  static const String startEx2Duration = '10 lần';
  static const String startEx3Title = 'Plank';
  static const String startEx3Duration = '20 giây';
  static const String startEx4Title = 'Giãn cơ toàn thân';
  static const String startEx4Duration = '90 giây';
  static const String btnStart5Min = 'Bắt đầu 5 phút';
  static const String btnScheduleFirstSession = 'Hẹn giờ cho buổi đầu';

  // Home
  static const String homeDate = 'Thứ Sáu, 26/9';
  static const String homeGreeting = 'Chào buổi chiều, Minh';
  static const String streakWeeks = '5 tuần';
  static const String thisWeekTitle = 'Tuần này';
  static const String thisWeekSessions = '2/3 buổi';
  static const String todayWorkoutHeader = 'Hôm nay · 18:30';
  static const String todayWorkoutTitle = 'Toàn thân + giãn cơ';
  static const String todayWorkoutMeta = '15 phút · 7 động tác · tạ đơn';
  static const String todayCoachNote = 'Coach: sáng nay bạn chọn "Mệt", nên mình đã bớt 1 hiệp.';
  static const String btnStart = 'Bắt đầu';
  static const String btnOnly5Min = 'Chỉ có 5 phút';
  static const String buddyFeedPrefix = 'Lan';
  static const String buddyFeedSuffix = ' đã tập xong hôm nay';
  static const String btnCheer = 'Cổ vũ';
  static const String caloRemaining = 'Calo còn lại';
  static const String caloValue = '820 / 1.800 kcal';
  static const String navToday = 'Hôm nay';
  static const String navNutrition = 'Dinh dưỡng';
  static const String navSnapFood = 'Chụp món ăn';
  static const String navCoach = 'Coach';
  static const String navProgress = 'Tiến độ';

  // Workout
  static const String workoutCloseAria = 'Thoát buổi tập';
  static const String workoutStep = '3/7';
  static const String workoutVideoPlaceholder = '[Video hướng dẫn động tác]';
  static const String workoutVideoPauseAria = 'Tạm dừng video';
  static const String workoutExName = 'Squat ôm tạ';
  static const String workoutSetMeta = 'Hiệp 2/3 · Lần trước: 10 lần × 6kg';
  static const String btnChangeExercise = 'Đổi bài';
  static const String weightKgLabel = 'Tạ (kg)';
  static const String repsLabel = 'Số lần';
  static const String formCue = 'Giữ lưng thẳng, dồn trọng tâm về gót chân. Gối hướng cùng chiều mũi chân.';
  static const String restAfterSet = 'Nghỉ 60 giây sau hiệp này';
  static const String voiceGuideOn = 'Hướng dẫn giọng nói: Bật';
  static const String btnCountCamera = 'Đếm bằng camera';
  static const String btnFinishSet = 'Xong hiệp này';
  static const String restTimerTitle = 'Nghỉ ngơi giữa hiệp';
  static const String restTimerSubtitle = 'Hít thở đều và uống nước';
  static const String btnSkipRest = 'Bỏ qua nghỉ';
}
