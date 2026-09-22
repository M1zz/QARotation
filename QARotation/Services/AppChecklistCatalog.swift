import Foundation

/// 스토어에 올린 앱마다 QA할 때 볼 전용 항목. 번들 ID로 찾는다(대소문자 무시).
/// 각 앱의 README·문서·소스에서 실제 기능을 읽고 뽑았다(소스가 없는 앱은 스토어 설명으로). 기본 체크리스트와 겹치는 것은 뺐다.
enum AppChecklistCatalog {
    static func key(_ bundleID: String) -> String {
        bundleID.trimmingCharacters(in: .whitespaces).lowercased()
    }

    static func items(for bundleID: String) -> [(ChecklistCategory, String)] {
        byKey[key(bundleID)] ?? []
    }

    private static let byKey: [String: [(ChecklistCategory, String)]] = Dictionary(
        uniqueKeysWithValues: itemsByBundleID.map { (key($0.key), $0.value) }
    )

    static let itemsByBundleID: [String: [(ChecklistCategory, String)]] = [
        // StickyPresenter
        "com.leeo.StickyPresenter": [
            (.platform, "전체 화면 Keynote 위에 스티키 노트가 보인다"),
            (.stability, "노트 색·투명도·잠금이 재실행 후 남는다"),
            (.custom, "⌘V로 클립보드 내용이 새 노트가 된다"),
            (.custom, "텔레프롬프터가 자동 스크롤되고 좌우 반전된다"),
            (.stability, "타이머 창이 첫 클릭부터 끌려 옮겨진다"),
            (.stability, "왼쪽 위 닫기 버튼이 위젯을 감추고 타이머는 계속 흐른다"),
            (.platform, "알림 센터 위젯에서 타이머가 줄어든다"),
        ],
        // StickyPresenterRemote
        "com.leeo.StickyPresenter.Remote": [
            (.platform, "Mac 목록이 뜨고 네 자리 코드로 짝이 맺어진다"),
            (.stability, "재실행하면 코드 없이 짝지은 Mac에 붙는다"),
            (.stability, "남은 시간·진행률이 1초마다 갱신된다"),
            (.custom, "시작·일시정지·±30초가 Mac 타이머에 반영된다"),
            (.custom, "미니 화면에서 끌면 Mac 위젯이 옮겨진다"),
            (.custom, "3/5/10/15분 프리셋으로 새 타이머가 시작된다"),
            (.stability, "연결 표시를 눌러 짝을 풀고 다른 Mac을 고를 수 있다"),
        ],
        // 골드위크
        "com.Ysoup.LeaveWise": [
            (.stability, "휴가 등록 후 재실행해도 남은 연차가 같다"),
            (.stability, "홈과 사용 내역의 사용 완료 일수가 같다"),
            (.custom, "캘린더 날짜를 눌러 그 날 휴가를 수정·삭제한다"),
            (.monetization, "무료는 추천 일부와 보너스 연차가 잠겨 있다"),
            (.platform, "연차 현황·D-Day 위젯이 남은 연차를 보여 준다"),
            (.custom, "공유 전에 연차 현황 이미지 미리보기가 뜬다"),
            (.stability, "타임머신 스냅샷에서 데이터가 복원된다"),
        ],
        // 낫마템포
        "com.leeo.HandsFreeMetronome": [
            (.custom, "\"start\"/\"stop\" 음성으로 재생·정지된다"),
            (.custom, "\"faster\"·\"tempo 120\" 음성에 BPM이 바뀐다"),
            (.stability, "느린 셋잇단 재생 중 음성 정지에도 크래시 없다"),
            (.stability, "마지막 템포·박자·분할이 재실행 후 남는다"),
            (.monetization, "무료는 연습 모드·악센트 에디터·튜너가 잠겨 있다"),
            (.stability, "전화·Siri가 끼어들면 메트로놈이 깨끗이 멈춘다"),
            (.appearance, "다운비트엔 빨강, 나머지 박엔 금색으로 화면이 번쩍인다"),
        ],
        // 달빛
        "com.leeo.LullabyRecipe": [
            (.stability, "화면을 잠가도 소리가 계속 재생된다"),
            (.platform, "잠금 화면 재생 컨트롤로 재생·일시정지가 된다"),
            (.custom, "타이머가 끝나면 소리가 서서히 줄며 멈춘다"),
            (.platform, "설정한 알람이 알람음과 함께 울린다"),
            (.custom, "달을 길게 누르면 즐겨찾기에 담긴다"),
            (.monetization, "무료는 내 사운드 3개 뒤로 저장이 막힌다"),
            (.stability, "만든 사운드가 재실행 후 보관함에 남는다"),
        ],
        // 달빛 오락실
        "com.example.MoonlitOrder": [
            (.custom, "게임방법에서 봇과 한 판을 끝까지 할 수 있다"),
            (.stability, "닉네임이 재실행 후 그대로 남는다"),
            (.platform, "방 만들기 때 로컬 네트워크 권한 요청이 뜬다"),
            (.custom, "게임 4종 카드가 각각 게임 메뉴를 연다"),
            (.stability, "게임 중 앱을 다시 열면 이어서 하기 카드가 보인다"),
            (.custom, "게임 중 화면이 자동으로 잠기지 않는다"),
            (.custom, "방장 왕관 버튼으로 GM 제어판이 열린다"),
        ],
        // 돈꼬마트
        "com.leeo.DontGoMart": [
            (.stability, "선택한 마트의 휴무일이 캘린더에 표시된다"),
            (.stability, "여러 마트 선택이 재실행 후 남는다"),
            (.custom, "커스텀 매장 휴무 패턴이 저장·표시된다"),
            (.platform, "알림이 설정한 시각에 정확히 온다"),
            (.platform, "전날 장보기 좋은 날 알림이 온다"),
            (.platform, "D-Day·일요일 영업 위젯이 맞게 보인다"),
            (.monetization, "후원 완료 시 콘페티와 ☕️ 배지가 뜬다"),
        ],
        // 두번알림
        "com.xa.toki": [
            (.platform, "종료 전 사전 알림이 설정 시점에 온다"),
            (.platform, "잠금 화면·다이내믹 아일랜드에 타이머가 보인다"),
            (.platform, "Apple Watch와 타이머가 동기화된다"),
            (.stability, "Pro에서 저장한 템플릿이 재실행 후 불러와진다"),
            (.monetization, "복원·코드 교환 직후 재실행 없이 잠금이 풀린다"),
            (.monetization, "무료는 템플릿 저장이 잠기고 시드는 남는다"),
            (.platform, "제어 센터 컨트롤로 타이머를 켜고 끈다"),
        ],
        // 마이파이
        "com.leeo.wifisnap": [
            (.custom, "연결된 와이파이가 큰 QR 카드로 보인다"),
            (.custom, "안내판을 찍으면 ID/PW가 인식돼 연결된다"),
            (.custom, "인식이 틀리면 퍼즐 조각을 끌어 고칠 수 있다"),
            (.stability, "저장된 네트워크가 재실행 후 남는다"),
            (.custom, "목록 행을 밀어 연결·QR 공유가 된다"),
            (.stability, "안내판 문구·테마가 재실행 후 남는다"),
            (.platform, "와이파이 QR 위젯이 고른 네트워크 QR을 보인다"),
        ],
        // 무지개 공방
        "com.devkoan.ScheduleDensityApp": [
            (.stability, "할 일을 요일에 끌어 놓으면 계획 블록이 된다"),
            (.stability, "빈 시간을 쓸어 내리면 그 범위에 일정이 잡힌다"),
            (.stability, "재실행 후에도 루틴·계획·백로그가 남는다"),
            (.platform, "공유 메뉴로 보낸 글이 백로그에 들어온다"),
            (.platform, "아이폰에서 적은 할 일이 백로그에 보인다"),
            (.custom, "타이머 멈출 때 적은 다음 첫 동작이 다시 보인다"),
            (.monetization, "출시 빌드에서는 Pro 잠금 표시가 안 보인다"),
        ],
        // 밑줄
        "com.leeo.bookmarkshot": [
            (.stability, "표지를 찍으면 제목·저자가 채워진다"),
            (.stability, "네 모서리를 맞추면 페이지가 반듯이 펴진다"),
            (.stability, "손가락으로 그은 문장만 추출된다"),
            (.stability, "저장한 문장이 재실행 후에도 서재에 남는다"),
            (.platform, "오늘의 문장 위젯이 스크랩을 보여 준다"),
            (.custom, "문장을 카드 이미지로 공유할 수 있다"),
            (.custom, "전체 문장 검색으로 스크랩이 찾아진다"),
        ],
        // 벅뚜벅뚜
        "com.leeo.FootprintDiary": [
            (.stability, "걸은 자리가 백지도에 점으로 찍힌다"),
            (.stability, "지도를 길게 누르면 도장이 찍힌다"),
            (.stability, "재실행 후에도 걸음·도장이 그대로 남는다"),
            (.appearance, "오늘 걸음은 붉게, 지난 걸음은 푸르게 보인다"),
            (.custom, "지도 아이콘을 누르는 동안만 배경 지도가 비친다"),
            (.custom, "달력 칸에 그날 걸은 모양이 보인다"),
            (.platform, "위젯이 오늘 그은 길 모양과 길이를 보여 준다"),
        ],
        // 불타는내인생
        "com.burningparchment.app": [
            (.stability, "설정한 취침시간까지 카운트다운이 흐른다"),
            (.platform, "다이나믹 아일랜드에 남은 시간이 보인다"),
            (.platform, "잠금화면 위젯이 취침까지 남은 시간을 보여 준다"),
            (.stability, "담은 재가 이번 주 항아리에 남아 있다"),
            (.custom, "항아리에 의미를 새기면 재에 색이 돈다"),
            (.appearance, "라이트 테마에서도 불꽃이 보인다"),
            (.monetization, "무료에선 데드라인이 1개까지만 만들어진다"),
        ],
        // 세끼
        "com.ysoup.RoutineCamera": [
            (.stability, "사진을 찍으면 시각에 맞는 끼니로 기록된다"),
            (.stability, "기록이 재실행 후에도 피드에 남는다"),
            (.platform, "위젯의 '다 먹음'이 앱 기록에 반영된다"),
            (.platform, "알림의 '다 먹음'으로 바로 기록된다"),
            (.platform, "단축어 '다 먹음'으로 기록이 남는다"),
            (.monetization, "AI 분석 시 코인이 1개 차감된다"),
            (.appearance, "운동 앨범이 날짜 붙은 3열 격자로 보인다"),
        ],
        // 쑥쑥용돈
        "com.family.FamilyBank": [
            (.stability, "용돈을 지급하면 잔액과 거래 기록에 남는다"),
            (.stability, "저축·투자 잔액이 재실행 후에도 남는다"),
            (.custom, "부모 모드는 PIN을 넣어야 열린다"),
            (.custom, "자녀 폰 모드는 PIN 없이 못 벗어난다"),
            (.custom, "모의 펀드 매수·매도가 잔액에 반영된다"),
            (.custom, "바코드를 찍으면 가게 물품이 결제된다"),
            (.custom, "자녀 초대 QR 코드가 보이고 공유된다"),
        ],
        // 아이일정
        "com.devkoan.CalendarSnap": [
            (.stability, "달력 사진에서 한 달 일정이 추출된다"),
            (.stability, "눕혀 찍은 달력 사진도 일정이 읽힌다"),
            (.stability, "추가한 일정이 재실행 후에도 남는다"),
            (.platform, "애플 캘린더에 중복 없이 일정이 들어간다"),
            (.platform, "준비물 메모가 알림 본문에 보인다"),
            (.platform, "위젯이 다가오는 일정을 보여 준다"),
            (.platform, "가족 초대 링크로 일정이 공유된다"),
        ],
        // 욕망의 무지개
        "com.example.ScheduleDensityApp": [
            (.stability, "일정이 겹칠수록 무지개 칸이 진해진다"),
            (.stability, "단계를 다 끝낸 할 일이 목록에서 내려간다"),
            (.platform, "번개 위젯이 지금 집을 단계를 보여 준다"),
            (.platform, "제어센터 버튼이 새 할 일 줄을 연다"),
            (.platform, "앱을 닫아도 타이머 종료 알림이 온다"),
            (.platform, "공유 시트로 보낸 글이 할 일에 추가된다"),
            (.monetization, "구매 전에는 위젯에 잠금 안내가 보인다"),
        ],
        // 우리집 가정법원
        "com.family.familycourt": [
            (.stability, "민사 소송 접수 후 사건 화면이 열린다"),
            (.stability, "판사는 원고·피고 외 사람만 고를 수 있다"),
            (.custom, "재판 타이머가 끝나면 알림음이 울린다"),
            (.custom, "판결 선고 때 의사봉 소리가 난다"),
            (.stability, "약속 체크가 재실행 후에도 남는다"),
            (.stability, "저장한 기록 파일을 불러오면 복원된다"),
            (.appearance, "말투 단계를 바꾸면 홈 문구가 바뀐다"),
        ],
        // 이어생각
        "com.leeo.thinkflow": [
            (.stability, "새 생각 스레드가 재실행 후에도 남는다"),
            (.stability, "끊어둘 문장 없이는 이어쓰기가 안 닫힌다"),
            (.stability, "브레인덤프 항목이 스레드로 승격된다"),
            (.stability, "엔트리 레이어 승급이 저장된다"),
            (.platform, "위젯이 끊어둔 문장을 보여 준다"),
            (.platform, "위젯을 탭하면 이어쓰기 화면이 열린다"),
            (.platform, "이어쓰기 중 Live Activity가 뜬다"),
        ],
        // 인생맛집
        "com.Ysoup.restaurantmap": [
            (.stability, "현재 위치로 추가한 식당 핀이 지도에 보인다"),
            (.custom, "지도에서 카카오 장소 검색 결과가 뜬다"),
            (.stability, "방문 기록과 사진이 재실행 후에도 남는다"),
            (.custom, "맛 평가 5개를 채우면 추천이 열린다"),
            (.stability, "상세 화면에서 Apple 지도로 이동한다"),
            (.custom, "추가한 음식 종류가 선택지에 보인다"),
            (.stability, "iCloud 백업이 오류 없이 끝난다"),
        ],
        // 장표스냅
        "com.leeo.slidesnap": [
            (.stability, "찍은 장표가 반듯하게 펴져 저장된다"),
            (.custom, "자동 촬영이 같은 장표를 다시 안 찍는다"),
            (.stability, "모서리 조정 후 보정본이 바뀐다"),
            (.custom, "텍스트 검색으로 장표를 찾는다"),
            (.custom, "PDF가 4장 레이아웃으로 내보내진다"),
            (.stability, "직접 만든 빈 발표가 사라지지 않는다"),
            (.platform, "잠금화면 위젯을 누르면 카메라가 열린다"),
        ],
        // 징검돌
        "com.leeo.ReboundJournal": [
            (.stability, "조약돌 대화 기록이 재실행 후에도 남는다"),
            (.custom, "음성으로 말한 내용이 대화에 들어간다"),
            (.stability, "지난 주 징검돌에서 기록이 보인다"),
            (.stability, "비밀번호 설정 후 재실행하면 잠긴다"),
            (.appearance, "비밀번호 숫자 버튼이 보인다"),
            (.custom, "영어 기기에서 대화가 영어로 나온다"),
            (.platform, "위젯을 누르면 기록 화면이 열린다"),
        ],
        // 초견
        "com.devkoan.StaffSinger": [
            (.stability, "오선을 탭하면 음표가 들어가고 소리가 난다"),
            (.custom, "재생하면 카운트인 뒤 현재 음표가 강조된다"),
            (.custom, "화음 모드로 쌓은 음이 동시에 울린다"),
            (.custom, "계이름을 말하면 음표로 들어간다"),
            (.custom, "텍스트 악보를 붙여넣으면 오선에 그려진다"),
            (.stability, "음길이·점음표 선택이 재실행 후에도 남는다"),
            (.appearance, "가로 모드에서 두 마디가 잘리지 않는다"),
        ],
        // 쿨타임
        "com.Ysoup.CoolTime": [
            (.stability, "아이템을 쓰면 쿨타임 원이 줄기 시작한다"),
            (.stability, "남은 쿨타임이 재실행 후에도 맞다"),
            (.custom, "쿨타임 중에 쓰면 경고가 뜬다"),
            (.custom, "템플릿으로 아이템이 추가된다"),
            (.custom, "통계에 준수율이 반영된다"),
            (.platform, "쿨타임이 끝나면 종료 알림이 온다"),
            (.platform, "홈 위젯이 쿨타임 현황을 보여 준다"),
        ],
        // 클립키보드: 전체 리그레션. ClipKeyboard 저장소의 FEATURE_MATRIX_AND_QA_4.4.4와
        // 4.4.5~5.1.5 릴리즈 노트의 실기기 확인 항목에서 뽑았다. 예전 7개 제목은 그대로 두었다.
        "com.Ysoup.TokenMemo": [
            // 첫 실행·튜토리얼
            (.stability, "첫 실행에 키보드 무대와 튜토리얼이 뜬다"),
            (.custom, "튜토리얼에서 단축어·템플릿·스택을 눌러 써 본다"),
            (.custom, "튜토리얼 끝에 연습 단축어를 치울지 한 번 묻는다"),
            (.stability, "튜토리얼을 마치고 재실행하면 다시 틀지 않는다"),
            (.custom, "설정에서 튜토리얼을 처음부터 다시 볼 수 있다"),
            (.platform, "설정 가이드대로 키보드와 전체 접근을 켤 수 있다"),
            (.platform, "키보드를 안 켰으면 키보드 화면 위에 켜기 띠가 남는다"),
            (.platform, "iOS 설정에서 키보드를 빼면 켜기 띠가 다시 뜬다"),
            (.custom, "목록 화면과 키보드 화면을 툴바로 오간다"),

            // 단축어 목록·편집
            (.stability, "새 단축어를 열자마자 이름 칸에 커서가 있다"),
            (.stability, "내용의 이메일 첫 글자가 대문자로 바뀌지 않는다"),
            (.custom, "저장하면 고른 카테고리 화면으로 옮겨 간다"),
            (.stability, "카드를 탭하면 복사되고 토스트가 탭바에 안 가린다"),
            (.custom, "카드를 꾹 눌러 수정·카테고리 이동·삭제 확인이 된다"),
            (.custom, "두 손가락 탭으로 여러 개 골라 옮기거나 지운다"),
            (.stability, "즐겨찾기해도 단축어가 원래 카테고리에 남는다"),
            (.stability, "카테고리를 좌우로 넘겨도 제목과 목록이 맞는다"),
            (.stability, "보던 카테고리가 비면 다음 카테고리로 넘어간다"),
            (.custom, "검색은 대소문자를 가리지 않고 보안 내용은 찾지 않는다"),
            (.custom, "작성 중 닫았다 다시 열면 초안이 돌아온다"),
            (.custom, "여러 줄을 붙여넣어 단축어 여러 개를 한 번에 만든다"),
            (.custom, "단축어 마트에서 빈칸만 채워 단축어를 만든다"),
            (.custom, "목록 맨 위 필수 단축어 세 칸을 채워 만든다"),
            (.custom, "앱을 열면 방금 복사한 글을 저장하자고 권한다"),
            (.stability, "카테고리를 숨길 때 안의 단축어를 한 번에 옮긴다"),

            // 템플릿·빈칸·스택
            (.custom, "템플릿 빈칸을 채워 입력된다"),
            (.custom, "빈칸에 친 값은 별을 눌러야만 저장된다"),
            (.custom, "빈칸 관리에서 끌어 바꾼 값 순서가 칩에 그대로 간다"),
            (.custom, "빈칸 이름을 바꾸면 쓰는 단축어 내용도 바뀐다"),
            (.custom, "날짜 빈칸이 설정한 날짜 형식으로 들어간다"),
            (.custom, "번호 빈칸은 다음 번호 칩이 맨 앞에 선다"),
            (.custom, "스택 칸 이름이 보이고 화살표로 값을 넘긴다"),
            (.stability, "스택 편집 중 칸을 지워도 앱이 멈추지 않는다"),

            // 사진·글자 읽기
            (.custom, "사진을 붙인 단축어를 누르면 사진이 복사된다"),
            (.custom, "글과 사진을 함께 담은 단축어가 둘 다 붙는다"),
            (.custom, "사진을 스캔해 문지른 글자만 내용으로 들어간다"),
            (.stability, "사진에서 읽은 카드번호는 보안 단축어로 잠긴다"),

            // 클립보드 기록
            (.custom, "다른 앱에서 복사한 글이 클립보드 기록에 쌓인다"),
            (.custom, "이메일·전화·주민번호가 맞는 종류로 분류된다"),
            (.custom, "클립보드 항목을 단축어로 저장할 수 있다"),
            (.custom, "설치 직후엔 붙여넣기 허용 팝업이 뜨지 않는다"),

            // 키보드 익스텐션 (실기기에서 남의 앱으로)
            (.platform, "키보드에서 단축어를 탭하면 입력된다"),
            (.platform, "앱에서 추가한 단축어가 키보드에 바로 보인다"),
            (.platform, "지구본 키로 다음 키보드로 넘어간다"),
            (.platform, "지구본을 길게 누르면 이모지 키보드를 고를 수 있다"),
            (.platform, "키보드가 마지막에 보던 카테고리로 열린다"),
            (.platform, "키를 길게 누르면 값이 크게 펼쳐지고 복사된다"),
            (.platform, "키보드 안에서 옮긴 단축어 순서가 남는다"),
            (.platform, "지우기 키를 누르고 있으면 계속 지워진다"),
            (.platform, "붙여넣기를 길게 눌러 복사한 글의 일부만 넣는다"),
            (.platform, "숫자 판이 열리고 가로에서도 아랫줄이 보인다"),
            (.platform, "키보드에서 두벌식·천지인 한글이 바르게 조합된다"),
            (.platform, "빠른 줄에 최근 쓴 것과 붙박이 단축어가 선다"),
            (.platform, "키보드에서 빈칸을 채울 때 지금 칸만 펼쳐진다"),
            (.platform, "잠긴 스택은 값을 넘길 땐 안 묻고 넣을 때 PIN을 묻는다"),
            (.platform, "키보드 높이를 시스템과 같게 하면 전환 때 안 튄다"),
            (.platform, "가로로 긴 사진 단축어가 옆 키를 가리지 않는다"),

            // 보안
            (.stability, "보안 단축어가 Face ID 후에 보인다"),
            (.stability, "Face ID를 못 쓰면 PIN으로 열 수 있다"),
            (.appearance, "잠근 단축어 카드에 자물쇠가 늘 보인다"),

            // 공유·위젯·제어센터
            (.platform, "공유 시트로 받은 글이 단축어가 된다"),
            (.platform, "즐겨찾기 위젯을 탭하면 복사된다"),
            (.platform, "제어센터 값 복사 버튼이 앱을 열지 않고 복사한다"),
            (.platform, "제어센터 빠른 메모가 앱을 열어 입력 시트를 띄운다"),

            // 데이터
            (.stability, "내보낸 .json을 가져오면 기존 데이터와 합쳐진다"),
            (.stability, "iCloud 백업을 복원하면 카테고리와 사진까지 돌아온다"),
            (.platform, "두 기기 동기화에서 수정·삭제도 반대편에 간다"),
            (.stability, "변경 기록에서 지운 단축어를 되돌린다"),
            (.stability, "모든 데이터 삭제 후 앱과 키보드가 모두 비어 있다"),
            (.stability, "구버전에서 올려도 단축어·카테고리·즐겨찾기가 남는다"),
            (.stability, "단축어가 수백 개여도 켜기·스크롤·검색이 끊기지 않는다"),
            (.stability, "기내 모드에서 로컬 기능은 되고 백업만 실패를 알린다"),

            // 설정·표시
            (.appearance, "키 컬러를 바꾸면 앱과 키보드가 함께 바뀐다"),
            (.appearance, "목록 배경에 내 사진을 넣고 지울 수 있다"),
            (.custom, "설정에서 언어를 바꾸면 재실행 없이 바뀐다"),
            (.custom, "나에게 맞추기에 판단 근거와 챙길 세 가지가 보인다"),
            (.custom, "사용 기록에서 아낀 시간을 기간별로 본다"),
            (.stability, "친구에게 알리기 영상을 만드는 동안 화면이 멈추지 않는다"),

            // 결제
            (.monetization, "무료 10개를 넘기면 결제 화면이 뜬다"),
            (.monetization, "결제 화면을 닫으면 하던 작업으로 돌아온다"),
            (.monetization, "무료 사용자에게는 iCloud 백업이 잠겨 있다"),
            (.monetization, "Pro 혜택 화면의 숫자가 실제와 맞다"),

            // 다국어·접근성·기기
            (.appearance, "영어·중국어·러시아어에서 문구가 잘리지 않는다"),
            (.appearance, "iPad에서 목록·시트·키보드가 화면에 맞게 놓인다"),
            (.accessibility, "VoiceOver가 키보드 지구본을 다음 키보드로 읽는다"),
            (.accessibility, "VoiceOver를 켜면 두 손가락 탭이 선택 화면을 안 연다"),
        ],
        // 탭클립키보드
        "com.ysoup.TokenMemo-tap": [
            (.platform, "⌃⇧V로 어디서나 빠른 붙여넣기 창이 뜬다"),
            (.stability, "항목을 누르면 복사되고 ⌘V 안내 후 창이 닫힌다"),
            (.stability, "팝오버에서 카테고리를 바꾸면 그 항목만 보인다"),
            (.custom, "템플릿을 고르면 값 채우기 창이 열린다"),
            (.stability, "방금 복사한 글이 클립보드 기록에 쌓인다"),
            (.platform, "아이폰에서 추가한 단축어가 맥에 동기화된다"),
            (.monetization, "\"무료 플랜·단축어 10개\" 문구가 보이지 않는다"),
        ],
        // 퇴사각
        "com.devkoan.FireTracker": [
            (.stability, "추가한 스냅샷이 재실행 후에도 남는다"),
            (.stability, "첫 화면 맨 위에 FIRE 달성률이 보인다"),
            (.stability, "저장한 계산을 불러오면 그때 입력값이 복원된다"),
            (.custom, "여정 탭 과녁 아이콘에서 목표를 고칠 수 있다"),
            (.custom, "앱 잠금을 켜면 Face ID를 통과해야 열린다"),
            (.stability, "백업 파일로 복원하면 기록이 되돌아온다"),
            (.appearance, "총자산/순자산 토글이 도넛 그래프에 반영된다"),
        ],
        // 팔랑북
        "com.leeo.RotoscopeiPad": [
            (.custom, "따라 그리기 세트를 고르면 가이드 선이 보인다"),
            (.custom, "도장을 탭하면 고른 크기로 찍힌다"),
            (.custom, "휴지통으로 지운 페이지가 되돌리기로 돌아온다"),
            (.platform, "펜슬 전용 모드에서는 손가락으로 그려지지 않는다"),
            (.custom, "길게 녹음한 목소리가 재생할 때 끝까지 나온다"),
            (.stability, "저장한 프로젝트를 다시 열면 그림이 남아 있다"),
            (.stability, "내보낸 결과가 사진 앱에 저장된다"),
        ],
        // 펀칭
        "com.devkoan.StampCamera": [
            (.stability, "촬영하면 우표 모양으로 잘려 수집함에 담긴다"),
            (.stability, "재실행해도 우표와 캡션이 남아 있다"),
            (.custom, "우표를 길게 눌러 전시 벽에 걸 수 있다"),
            (.platform, "스티커 키보드에서 우표를 누르면 복사된다"),
            (.platform, "메시지 스티커 서랍에 모은 우표가 보인다"),
            (.platform, "Siri에 \"꾹 열기\"라고 하면 카메라가 바로 열린다"),
            (.custom, "컬렉션에서 인쇄용 스티커 시트 PDF가 만들어진다"),
        ],
        // 픽셀미미
        "com.leeo.PixelMe": [
            (.stability, "사진을 고르면 픽셀 아트로 바뀐다"),
            (.monetization, "무료 사용자는 하루 3회 변환 후 막힌다"),
            (.monetization, "앱을 다시 켜도 무료 변환 횟수가 유지된다"),
            (.monetization, "무료로 저장하면 워터마크가 찍힌다"),
            (.monetization, "무료는 원본 팔레트와 CRT 필터만 쓸 수 있다"),
            (.custom, "픽셀 에디터에서 되돌리기가 된다"),
            (.custom, "Pro에서 GIF 내보내기가 된다"),
        ],
        // 하늘색
        "com.leeo.SkyDex": [
            (.stability, "하늘을 찍으면 그 시각의 칸이 채워진다"),
            (.stability, "재실행해도 찍은 하늘이 판에 남아 있다"),
            (.custom, "촬영 중 핀치로 확대되고 배율이 보인다"),
            (.stability, "카메라를 켜자마자 셔터를 눌러도 안 꺼진다"),
            (.platform, "\"오늘의 판\" 위젯에 채운 칸이 보인다"),
            (.platform, "\"오늘의 하늘\" 위젯에 오늘 사진과 색이 보인다"),
            (.custom, "사진 상세에 하늘색 이름이 보인다"),
        ],
        // 한국길찾기
        "com.kora.leeo": [
            (.stability, "출발역과 도착역을 고르면 경로가 나온다"),
            (.stability, "재실행해도 출발역과 도착역이 남아 있다"),
            (.platform, "탑승 중 잠금화면에 라이브 액티비티가 뜬다"),
            (.platform, "앱을 스와이프로 종료하면 라이브 액티비티도 사라진다"),
            (.appearance, "탑승 중 긴 역 이름이 잘리지 않는다"),
            (.custom, "승강장 표지판을 스캔하면 방향이 맞게 나온다"),
            (.custom, "표시 언어를 바꾸면 역 이름도 바뀐다"),
        ],
        // 햇빛바라기
        "com.leeo.sunflower": [
            (.stability, "밝은 실외에 있으면 햇빛 기록이 자동으로 시작된다"),
            (.platform, "트래킹 중 다이나믹 아일랜드에 충전량이 보인다"),
            (.stability, "배터리가 1% 미만일 때 전달 슬라이더를 움직여도 안 꺼진다"),
            (.stability, "재실행해도 해바라기 상태와 배터리가 남아 있다"),
            (.platform, "홈 위젯에 해바라기와 배터리가 보인다"),
            (.platform, "정해 둔 시간에 햇빛 알림이 온다"),
            (.custom, "기록 탭 캘린더에 기분 이모지가 남아 있다"),
        ],
        // Externalize
        "com.devkoan.externalize": [
            (.stability, "재실행해도 아직 만료되지 않은 메모가 남아 있다"),
            (.custom, "메모를 탭하면 값이 복사된다"),
            (.custom, "스와이프하면 만료가 24시간 늘어난다"),
            (.custom, "만료 시간이 지난 메모는 목록에서 사라진다"),
            (.platform, "잠금화면 위젯에 저장한 메모가 보인다"),
            (.platform, "Siri에 \"뇌모리에 기억해\"라고 하면 저장된다"),
            (.monetization, "무료 사용자는 3번째 메모를 저장할 수 없다"),
        ],
        // 꿈을 찾아서 (BucketClimb)
        "com.bucketclimb.app": [
            (.custom, "새 꿈과 단계를 추가하면 창고에 뜬다"),
            (.custom, "꿈의 바다 상자를 창고로 가져온다"),
            (.custom, "단계 완료 시 톱니 진행률이 오른다"),
            (.stability, "꿈과 진행 기록이 재실행 후에도 남는다"),
            (.custom, "대표 사진을 바꾸면 재실행 후 유지된다"),
            (.platform, "지도 탭에 위치 지정한 꿈이 표시된다"),
            (.custom, "클래식 모드를 켜면 꿈 키우기 탭으로 바뀐다"),
        ],
        // 라포맵 (RapportMap)
        "com.ysoup.RapportMap": [
            (.platform, "연락처에서 선택해 사람을 추가한다"),
            (.custom, "빠른 기록이 사람 타임라인에 쌓인다"),
            (.platform, "만남 녹음이 텍스트로 변환된다"),
            (.platform, "캘린더에 미팅 일정이 추가된다"),
            (.platform, "액션 리마인더 알림이 제시간에 온다"),
            (.stability, "재실행하면 보던 사람 화면이 복원된다"),
            (.stability, "iCloud 백업 후 복원(병합)이 된다"),
        ],
        // 링롱 (FindMe)
        "com.leeo.FindMe": [
            (.custom, "제목과 메모를 넣으면 QR이 생성된다"),
            (.platform, "QR을 스캔하면 App Clip이 메모를 보여 준다"),
            (.platform, "클립에서 띵똥을 누르면 주인에게 푸시가 온다"),
            (.custom, "받은 확인 알림이 알림 탭에 쌓인다"),
            (.custom, "QR 사진 저장과 링크 복사가 된다"),
            (.stability, "저장한 메모가 재실행 후에도 남는다"),
            (.custom, "설정한 내 이름이 클립 화면에 표시된다"),
        ],
        // 사노라면 (IndonesianSmallTalk)
        "com.devkoan.IndonesianSmallTalk": [
            (.custom, "트리 대화를 끝내면 결과와 복습이 나온다"),
            (.platform, "음성 모드에서 말하면 인식되어 매칭된다"),
            (.platform, "표현 키보드가 인니어를 입력한다"),
            (.stability, "새로 추가한 내 표현이 키보드에 반영된다"),
            (.platform, "친구와 공유한 스몰토크가 양쪽에 동기화된다"),
            (.custom, "AI로 만든 시나리오가 홈에 추가된다"),
            (.custom, "단어장에서 단어 발음이 재생된다"),
        ],
        // 스픽플로우 (ConversationPractice)
        "com.leeo.ConversationPractice": [
            (.custom, "시나리오 대화가 음성 인식으로 진행된다"),
            (.custom, "TTS 재생 중이라는 상태가 표시된다"),
            (.custom, "발음 연습 후 점수가 표시된다"),
            (.custom, "자유 대화에서 번역이 함께 보인다"),
            (.custom, "JSON 가져오기로 시나리오가 추가된다"),
            (.stability, "내 시나리오와 대화 기록이 재실행 후에도 남는다"),
            (.stability, "선택한 언어가 재실행 후에도 유지된다"),
        ],
        // 실수 100 (JuniorDevMistakes)
        "com.leeo.JuniorDevMistakes": [
            (.monetization, "무료는 앞 3개 카테고리만 열린다"),
            (.monetization, "잠긴 카테고리를 누르면 결제 화면이 뜬다"),
            (.custom, "실수 체크 시 진행률 탭 수치가 오른다"),
            (.stability, "체크·북마크가 재실행 후에도 남는다"),
            (.custom, "회고 답변 저장 후 회고 일지에 보인다"),
            (.custom, "회고 일지 항목을 삭제할 수 있다"),
            (.stability, "데이터 초기화 후 진행률이 0이 된다"),
        ],
        // 앱 디자인 실습 (HigGym)
        "com.leeo.higgym": [
            (.custom, "레슨 5단계를 끝까지 넘길 수 있다"),
            (.custom, "비교 단계에서 고친·어긴 화면이 바뀐다"),
            (.stability, "열어만 본 레슨은 빈 노트를 안 남긴다"),
            (.stability, "레슨 진도·노트가 재실행 후에도 남는다"),
            (.platform, "노트를 마크다운 파일로 공유할 수 있다"),
            (.custom, "목업 부위를 누르면 설명이 나온다"),
            (.custom, "퀴즈 오답이 복습 목록에 쌓인다"),
        ],
        // 오늘의 주접 (Jujob)
        "com.leeo.JuJob": [
            (.platform, "홈 화면 위젯에 주접 문구가 보인다"),
            (.platform, "배경·글꼴을 바꾸면 위젯에 반영된다"),
            (.custom, "다음 주접 누르면 새 문구로 바뀐다"),
            (.stability, "즐겨찾기가 재실행 후에도 남는다"),
            (.custom, "본 주접이 히스토리에 기록된다"),
            (.custom, "이름 설정 미리보기에 내 이름이 뜬다"),
            (.monetization, "무료는 앞 2개 카테고리만 열린다"),
        ],
        // 확률계산기 (LottoChecker)
        "com.lottochecker.app": [
            (.stability, "첫 실행에 면책 안내가 한 번만 뜬다"),
            (.custom, "번호 선택 시 현재 확률이 바로 바뀐다"),
            (.custom, "최신 회차 당첨번호와 보너스가 보인다"),
            (.custom, "이전/다음으로 회차를 넘길 수 있다"),
            (.stability, "구매 내역이 재실행 후에도 남는다"),
            (.custom, "저장한 조합의 회차 일치 개수가 나온다"),
            (.stability, "오프라인에서도 본 회차가 캐시로 뜬다"),
        ],
        // LeeoCon
        "com.leeo.LeeoCon": [
            (.platform, "메시지 앱 스티커 서랍에 LeeoCon이 보인다"),
            (.platform, "스티커를 눌러 대화에 보낼 수 있다"),
            (.platform, "스티커를 끌어 말풍선 위에 붙일 수 있다"),
            (.appearance, "스티커 가장자리가 깨지거나 잘리지 않는다"),
            (.appearance, "다크 모드 대화창에서도 스티커가 잘 보인다"),
        ],
        // TetraTint
        "com.leeo.TetraTint": [
            (.custom, "고른 두 색의 대비 비율이 보인다"),
            (.custom, "대비가 기준에 못 미치면 바로 알 수 있다"),
            (.custom, "색 값을 눌러 복사할 수 있다"),
            (.stability, "고른 색이 재실행 후에도 남는다"),
            (.platform, "창 크기를 줄여도 색 견본이 잘리지 않는다"),
        ],
        // 여울
        "com.leeo.yeoul": [
            (.stability, "타임라인에 사건을 추가하면 날짜 순으로 놓인다"),
            (.stability, "추가한 사건을 고치고 지울 수 있다"),
            (.stability, "타임라인이 재실행 후에도 남는다"),
            (.custom, "타임라인을 출력·내보내기 할 수 있다"),
            (.appearance, "사건이 많아도 타임라인 글자가 겹치지 않는다"),
        ],
        // 질문노트
        "com.lectureq.LectureQ": [
            (.stability, "질문을 적고 그 아래에 메모를 달 수 있다"),
            (.stability, "적은 질문과 메모가 재실행 후에도 남는다"),
            (.custom, "질문 목록에서 원하는 질문을 찾을 수 있다"),
            (.custom, "질문을 고치고 지울 수 있다"),
            (.platform, "단축키로 새 질문을 바로 만들 수 있다"),
        ],
    ]
}
