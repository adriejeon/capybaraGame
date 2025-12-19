import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_environment.dart';

/// 뽑기권 관리자
/// 게임 완료 시 뽑기권 1개 획득 (하루 최대 3회)
/// 뽑기권으로 캐릭터 뽑기 가능
class TicketManager {
  static const String _ticketCountKey = 'gacha_ticket_count';
  static const String _dailyEarnedCountKey = 'daily_ticket_earned_count';
  static const String _lastEarnedDateKey = 'last_ticket_earned_date';
  static const String _testTicketsInitializedKey = 'test_tickets_initialized';
  static const int maxDailyTickets = 3; // 하루 최대 뽑기권 획득 횟수
  static const int testEnvironmentTicketCount = 100; // 테스트 환경에서 초기 코인 개수

  static final TicketManager _instance = TicketManager._internal();
  factory TicketManager() => _instance;
  TicketManager._internal();

  int _ticketCount = 0;
  int _dailyEarnedCount = 0;
  String _lastEarnedDate = '';

  /// 초기화
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _ticketCount = prefs.getInt(_ticketCountKey) ?? 0;
    _dailyEarnedCount = prefs.getInt(_dailyEarnedCountKey) ?? 0;
    _lastEarnedDate = prefs.getString(_lastEarnedDateKey) ?? '';

    // 날짜가 바뀌었으면 일일 획득 횟수 초기화
    final today = _getTodayString();
    if (_lastEarnedDate != today) {
      _dailyEarnedCount = 0;
      _lastEarnedDate = today;
      await _save();
    }

    // 테스트 환경에서 초기 코인 설정 (한 번만 실행)
    await _initializeTestTickets(prefs);
  }

  /// 테스트 환경에서 초기 코인 설정
  Future<void> _initializeTestTickets(SharedPreferences prefs) async {
    try {
      // 앱스토어 버전이 아닌 경우에만 테스트 코인 설정
      final isAppStore = await AppEnvironment.isAppStore();
      if (isAppStore) {
        print('[TicketManager] 앱스토어 환경 - 테스트 코인 설정 안 함');
        return;
      }

      // 이미 테스트 코인이 설정되었는지 확인
      final testTicketsInitialized = prefs.getBool(_testTicketsInitializedKey) ?? false;
      if (testTicketsInitialized) {
        print('[TicketManager] 테스트 코인 이미 설정됨 - 현재: $_ticketCount개');
        return;
      }

      // 테스트 환경에서 초기 코인 설정
      _ticketCount = testEnvironmentTicketCount;
      await prefs.setBool(_testTicketsInitializedKey, true);
      await _save();
      
      final environment = await AppEnvironment.getCurrentEnvironment();
      print('[TicketManager] 테스트 환경 감지 ($environment) - 초기 코인 $testEnvironmentTicketCount개 설정 완료');
    } catch (e) {
      print('[TicketManager] 테스트 코인 설정 중 오류: $e');
    }
  }

  /// 현재 뽑기권 개수
  int get ticketCount => _ticketCount;

  /// 오늘 획득한 뽑기권 개수
  int get dailyEarnedCount => _dailyEarnedCount;

  /// 오늘 더 획득 가능한 뽑기권 개수
  int get remainingDailyTickets => maxDailyTickets - _dailyEarnedCount;

  /// 오늘 뽑기권 획득 가능 여부
  bool get canEarnTicketToday => _dailyEarnedCount < maxDailyTickets;

  /// 뽑기권 획득 (게임 완료 시 호출)
  /// 반환값: 획득 성공 여부
  Future<bool> earnTicket() async {
    // 날짜 체크 및 초기화
    final today = _getTodayString();
    if (_lastEarnedDate != today) {
      _dailyEarnedCount = 0;
      _lastEarnedDate = today;
    }

    // 일일 제한 체크
    if (_dailyEarnedCount >= maxDailyTickets) {
      print('[TicketManager] 오늘 뽑기권 획득 한도 초과');
      return false;
    }

    // 뽑기권 획득
    _ticketCount++;
    _dailyEarnedCount++;
    await _save();
    print('[TicketManager] 뽑기권 획득! 현재: $_ticketCount개, 오늘: $_dailyEarnedCount/$maxDailyTickets');
    return true;
  }

  /// 뽑기권 사용 (캐릭터 뽑기 시 호출)
  /// 반환값: 사용 성공 여부
  Future<bool> useTicket() async {
    if (_ticketCount <= 0) {
      print('[TicketManager] 뽑기권이 없습니다');
      return false;
    }

    _ticketCount--;
    await _save();
    print('[TicketManager] 뽑기권 사용! 남은 개수: $_ticketCount');
    return true;
  }

  /// 뽑기권 추가 (특별 보상 등)
  Future<void> addTickets(int count) async {
    _ticketCount += count;
    await _save();
    print('[TicketManager] 뽑기권 $count개 추가! 현재: $_ticketCount개');
  }

  /// 오늘 날짜 문자열 반환
  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 데이터 저장
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_ticketCountKey, _ticketCount);
    await prefs.setInt(_dailyEarnedCountKey, _dailyEarnedCount);
    await prefs.setString(_lastEarnedDateKey, _lastEarnedDate);
  }

  /// 디버그용: 데이터 초기화
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ticketCountKey);
    await prefs.remove(_dailyEarnedCountKey);
    await prefs.remove(_lastEarnedDateKey);
    await prefs.remove(_testTicketsInitializedKey); // 테스트 코인 초기화 플래그도 제거
    _ticketCount = 0;
    _dailyEarnedCount = 0;
    _lastEarnedDate = '';
    print('[TicketManager] 데이터 초기화 완료');
  }

  /// 테스트용: 테스트 코인 재설정 (테스트 코인 초기화 플래그 제거 후 재초기화)
  Future<void> resetTestTickets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_testTicketsInitializedKey);
    print('[TicketManager] 테스트 코인 재설정 플래그 제거 완료');
    // 다음 initialize 호출 시 다시 설정됨
  }
}


