/// realm-swift 를 다시 내보냅니다.
///
/// 다른 모듈은 `import RealmSwift` 대신 `import ThirdParty_Realm` 을 씁니다.
/// SDK 의존이 이 파일 한 곳에 모여 있어, 저장 기술을 바꿀 때 영향 범위가 이 패키지로 좁혀집니다.
///
/// 다시 내보낸다고 해서 Realm 타입을 어디서나 쓸 수 있다는 뜻은 아닙니다.
/// 이 모듈을 의존하는 것은 `Core_Persistence` 하나뿐이고, 그 안에서도 Realm 타입은
/// `internal` 로 묶여 패키지 밖으로 나가지 않습니다. 두 장치가 함께 경계를 만듭니다.
@_exported import RealmSwift
