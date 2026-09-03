# DESIGN

모듈 구조, 의존성, 상태 흐름, 그리고 각 선택의 대가를 적었습니다.

---

## 1. 모듈 구조

로컬 SPM 패키지 5개와 앱 타깃 1개입니다.

| 모듈 | 역할 | 아는 것 | 모르는 것 |
|---|---|---|---|
| **Core_Domain** | 모델(`Photo`), 실패 표현(`AppError`), 저장소 계약(`PhotoRepository`, `PhotoDataLoader`) | 없음 | 저장 기술, 화면, 특정 API |
| **Core_Networking** | 전송 계층. `URLSession` 요청/응답, 실패 분류, 이미지 바이너리 내려받기, 연결 감시 | 없음 | 도메인, 특정 API |
| **ThirdParty_Realm** | Realm SDK 어댑터 | Realm | 이 앱의 도메인 |
| **Core_Persistence** | Realm 메타데이터 저장, 이미지 파일 보관 | 도메인, Realm | 네트워크 |
| **Core_Service** | TheCatAPI 명세, 응답 변환, 저장소 구현체 | 도메인·전송·저장 | 화면 |
| **MillieCat** (앱) | 상태 계층(MVI), 화면, 조립 지점 | 전부 | — |

**모듈을 나눈 기준은 "무엇을 모르는가"입니다.** `Core_Networking` 이 TheCatAPI 를 모르기 때문에 다른 API 를 쓰는 프로젝트에 그대로 옮길 수 있고, `Core_Domain` 이 Realm 을 모르기 때문에 저장 기술을 바꿔도 도메인은 그대로입니다.

TheCatAPI 의 주소·파라미터·응답 형식은 전송 계층이 아니라 `Core_Service` 에 있습니다. 초안에서는 `Endpoint` 안에 주소를 함께 두었는데, 그러면 전송 계층이 특정 API 에 묶여 의존성 0 을 유지할 수 없었습니다.

---

## 2. 의존성

각 `Package.swift` 에 선언된 그대로입니다. 화살표는 "쓴다"는 뜻이고, 반대 방향은 없습니다.

```
                    MillieCat (앱)
                      │        │
        ┌─────────────┘        └──────────────┐
        ▼                                     ▼
  Core_Service ────────────────────────▶ Core_Domain
        │      │                              ▲
        │      └──────▶ Core_Networking       │
        │                (의존성 0)            │
        ▼                                     │
  Core_Persistence ───────────────────────────┘
        │
        ▼
  ThirdParty_Realm ──▶ realm-swift 20.0.5
```

| 모듈 | 선언한 의존 |
|---|---|
| `Core_Domain` | 없음 |
| `Core_Networking` | 없음 |
| `ThirdParty_Realm` | realm-swift |
| `Core_Persistence` | `Core_Domain`, `ThirdParty_Realm` |
| `Core_Service` | `Core_Domain`, `Core_Networking`, `Core_Persistence` |
| `MillieCat` (앱) | `Core_Domain`, `Core_Service` |

앱은 `Core_Networking` 과 `Core_Persistence` 를 직접 선언하지 않았는데도 조립 지점에서 `import` 해서 씁니다. SPM 이 전이 의존을 열어 두기 때문이고, 이것이 아래에서 말하는 약한 지점입니다.

### 경계를 지키는 수단은 계층마다 다릅니다

여기는 정확하게 적을 필요가 있습니다. **모든 경계가 컴파일러로 막히지는 않습니다.**

| 경계 | 무엇이 막는가 |
|---|---|
| `Core_Domain` · `Core_Networking` 이 남을 쓰는 것 | **컴파일러.** 의존성이 0이라 `import` 자체가 실패합니다 |
| Realm 타입이 패키지 밖으로 나가는 것 | **접근 제어.** `PhotoObject` 가 `internal` 이라 밖에서 볼 수 없습니다 |
| `Core_Service` 가 `ThirdParty_Realm` 을 직접 쓰는 것 | **막히지 않습니다.** SPM 이 전이 의존을 열어 두어 `import` 가 통과합니다 |

마지막 줄이 이 구조의 약한 지점입니다. 확인 방법은 금지하려는 `import` 를 일부러 넣고 **깨끗한 경로에서** 빌드해 보는 것입니다. 남아 있는 빌드 산출물이 있으면 막혀야 할 `import` 가 그냥 통과하므로 `--scratch-path` 로 확인했습니다.

앞선 두 계층이 막혔던 것은 규칙이 잘 서 있어서가 아니라 **의존성이 0이라 전이 경로 자체가 없었기** 때문입니다. 처음에는 이것을 "경계가 컴파일러로 강제된다"고 일반화해 적었다가, 실제로 확인해 보고 고쳤습니다.

---

## 3. 상태 흐름

### 한 덩어리 상태와 순수 함수

```
입력(Intent) ──▶ Store ──▶ 저장소 호출 ──▶ 결과(Event) ──▶ Reducer ──▶ State ──▶ 화면
                                                            (순수 함수)
```

| 조각 | 파일 | 하는 일 |
|---|---|---|
| `PhotoListIntent` | `PhotoListState.swift` | 밖에서 들어오는 입력 |
| `PhotoListStore` | `PhotoListStore.swift` | 무엇을 언제 시킬지 판단 |
| `PhotoListEvent` | `PhotoListState.swift` | 요청의 결과 |
| `reduce` | `PhotoListReducer.swift` | 상태를 바꾸는 **유일한** 곳 |
| `PhotoListState` | `PhotoListState.swift` | 화면이 보는 값 전부 |

로딩 여부와 실패 여부를 각각 따로 두면 "로딩 중인데 에러도 표시" 같은 있을 수 없는 조합이 만들어집니다. `phase` 를 열거형 하나로 두어 그런 조합을 타입 차원에서 불가능하게 했습니다.

### 앱을 켰을 때 흐르는 경로

```
PhotoListView.task
   └─ .onAppear ──▶ PhotoListStore.send
        └─ NetworkFirstPhotoRepository.loadNext
             ├─ 성공 ─▶ MetadataStore.upsert (저장)  ─▶ .loaded(source: .network)
             └─ 실패 ─▶ MetadataStore.fetchShuffled  ─▶ .loaded(source: .cache)
                          └─ 저장된 것도 없으면      ─▶ .failed(AppError)
```

칸의 이미지는 별도 경로입니다.

```
PhotoCell.task ──▶ CacheFirstPhotoDataLoader.data
                     ├─ 저장된 것이 있으면 그것을 씁니다 (온라인이어도)
                     └─ 없으면 내려받고 저장합니다
```

**메타데이터와 이미지의 정책 방향이 반대입니다.** 목록은 최신이어야 하므로 네트워크가 먼저이고, 이미지는 한 번 받으면 바뀌지 않으므로 저장된 것이 먼저입니다. 이 차이가 이름에 드러나도록 `NetworkFirstPhotoRepository` / `CacheFirstPhotoDataLoader` 로 지었습니다.

### 비동기를 두 가지로 나눈 기준

| 성격 | 도구 | 예 |
|---|---|---|
| 요청 한 번 → 결과 한 번. 시작과 끝이 있음 | **Swift Concurrency** | 목록 요청, 이미지 내려받기, Realm 읽기·쓰기 |
| 끝이 없고 값이 몇 번 올지 모름 | **Combine** | 연결이 끊기고 붙는 것, 상태가 바뀌었다는 알림 |

연결 상태는 `await` 로 "다음 변화 하나를 기다린다"까지만 표현됩니다. 값이 올 때마다 반응해야 하는 일이라 통로를 미리 만들어 두는 쪽이 맞습니다.

```
ConnectivityMonitor.isOnline ─▶ filter { $0 } ─▶ .connectionRestored
                                                      └─ 저장된 것을 보고 있거나
                                                         실패한 상태일 때만 다시 불러옵니다
```

잘 보고 있는데 연결 신호만으로 목록을 갈아치우면 보던 자리를 잃습니다. 그래서 `.retry` 와 조건이 다릅니다.

### 의존성이 실제로 꽂히는 곳

구현체를 고르는 곳은 `MillieCatApp.swift` 한 곳뿐입니다. 화면과 상태 계층은 계약만 알고, 그 자리에 무엇이 들어가는지 모릅니다. 덕분에 테스트에서는 같은 자리에 대역을 넣어 화면 없이 동작을 확인합니다.

---

## 4. 트레이드오프

### MVI 를 골랐습니다

오프라인 × 로딩 × 실패 × 캐시 조합이 많은 화면입니다. 상태를 여러 프로퍼티로 흩어 두면 있을 수 없는 조합이 만들어지고, 그것을 막는 코드가 화면 곳곳에 생깁니다.

**대가**: 화면 하나에 파일이 4개(State/Intent·Reducer·Store·View) 생깁니다. 단순한 화면이었다면 MVVM 이 더 짧았을 것입니다.

### `throws(AppError)` 를 썼습니다

시그니처만 보고 어떤 실패가 오는지 알 수 있고, `switch` 에서 빠뜨린 경우를 컴파일러가 잡아 줍니다.

**대가**: 존재 타입(`any PhotoRepository`)을 거치면 오류 타입이 `any Error` 로 지워집니다. 그래서 `PhotoListStore` 를 제네릭으로 만들어야 했습니다. 이 제약은 고르기 전에 예상했고 실제로 나타났습니다.

### Realm 을 메서드마다 새로 엽니다

Realm 인스턴스는 스레드에 묶여 있는데 actor 는 호출 사이에 같은 스레드를 보장하지 않습니다. 인스턴스를 붙들고 있으면 다른 스레드에서 접근하는 순간 깨집니다.

**대가**: 호출마다 여는 비용이 듭니다. 이 앱의 호출 빈도에서는 문제가 되지 않는 수준입니다.

### 패키지 밖으로 나가는 것은 값 타입뿐입니다

Realm 객체는 `internal` 이라 밖으로 못 나가고, 경계에서 `Photo` 값으로 바뀝니다.

**대가**: 변환 코드가 필요하고, Realm 의 지연 로딩·자동 갱신 같은 이점을 포기합니다. 얻는 것은 Swift 6 동시성 검사를 그대로 통과하는 것과, 저장 기술을 바꿔도 위 계층이 그대로인 것입니다.

### 가로에서 줄마다 좌우로 스크롤합니다

한 줄에 다섯 칸이 들어가고, 줄이 각자 좌우 스크롤을 맡습니다. 바깥은 위아래로만 움직입니다.

**대가**: 화면 폭이 874pt 라 **한 번에 약 3칸만 보입니다.** 나머지는 오른쪽으로 밀어야 나옵니다. 격자 전체를 두 방향으로 스크롤시키면 다섯 칸이 한눈에 들어오지는 않더라도 구조는 단순했겠지만, 아래로 내리는 동안 좌우 위치까지 함께 밀려 보던 자리를 놓치게 됩니다. 세로 이동과 가로 이동을 분리하는 쪽을 골랐습니다.

### 로컬 SPM 으로 나눴습니다

폴더만 나누면 규칙은 사람이 지켜야 합니다. 패키지로 나누면 최소한 의존성 0인 모듈에서는 컴파일러가 막아 줍니다.

**대가**: 첫 빌드가 깁니다. Realm 이 realm-core(C++)를 소스에서 컴파일하기 때문입니다. 패키지가 늘수록 설정 파일도 늘어납니다.

### Alamofire 를 쓰지 않았습니다

필요한 것이 GET 요청, 상태 코드 분류, JSON 디코딩, 바이너리 내려받기뿐이라 `URLSession` 으로 충분했습니다. 외부 의존성이 하나 줄어 클론 후 첫 빌드가 실패할 여지도 줄었습니다.

**대가**: 재시도·인증 같은 것이 나중에 필요해지면 직접 만들어야 합니다.

### 화면 자동화 테스트가 실제 서버를 씁니다

앱을 그대로 띄워 눌러 보기 때문에, 실제로 동작하는지를 가장 가깝게 확인합니다.

**대가**: 연결이 없거나 호출 제한에 걸리면 기능과 무관하게 실패합니다. 대역으로 바꾸려면 앱에 테스트 전용 통로를 내야 해서, 지금은 한계로 두고 대기 시간을 넉넉히 두었습니다.

---

## 확인한 범위

| 항목 | 수 |
|---|---|
| 패키지 단위 테스트 | 42 |
| 앱 타깃 단위 테스트 | 35 |
| 화면 자동화 테스트 | 3 |

깨끗하게 클론한 상태에서 전체 실행이 통과하는 것을 확인했습니다.
