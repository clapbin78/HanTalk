Pod::Spec.new do |s|
  s.name             = 'HanChatKit'
  s.version          = '0.1.0'
  s.summary          = '어떤 iOS 앱에도 붙는 채팅 SDK — 24시간 뒤 사라지는 메시지, 그리는 과정이 재생되는 그림 메시지'
  s.description      = <<-DESC
    Clean Architecture + MVVM 기반 채팅 솔루션.
    1:1/그룹 채팅, 연락처 기반 친구 찾기(전체/선택 등록), 벡터 그림 메시지(그리기 과정 재생),
    서버 미보관(우체통 모델) + 기기 24시간 자동삭제. 백엔드는 프로토콜로 교체 가능(Firebase 어댑터 제공).
  DESC
  s.homepage         = 'https://github.com/clapbin78/HanTalk'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '천재' => 'clapbinbox@gmail.com' }
  # 주의: CocoaPods/SPM 정식 배포 시 HanChatKit을 별도 저장소로 분리 필요 (Package.swift가 루트여야 함)
  s.source           = { :git => 'https://github.com/clapbin78/HanChatKit.git', :tag => s.version.to_s }
  s.swift_version    = '5.9'
  s.ios.deployment_target = '17.0'

  # ⚠️ CocoaPods trunk는 2026-12-02부터 read-only.
  #    등록하려면 그 전에 `pod trunk push HanChatKit.podspec` 실행. 이후 신규 배포는 SPM으로.

  s.default_subspec = 'UI'

  s.subspec 'Core' do |core|
    core.source_files = 'Sources/HanChatCore/**/*.swift'
  end

  s.subspec 'Data' do |data|
    data.source_files = 'Sources/HanChatData/**/*.swift'
    data.dependency 'HanChatKit/Core'
  end

  s.subspec 'UI' do |ui|
    ui.source_files = 'Sources/HanChatUI/**/*.swift'
    ui.resource_bundles = { 'HanChatUI' => ['Sources/HanChatUI/Resources/**/*'] }
    ui.dependency 'HanChatKit/Data'
  end

  s.subspec 'Firebase' do |fb|
    fb.source_files = 'Sources/HanChatFirebase/**/*.swift'
    fb.dependency 'HanChatKit/Data'
    fb.dependency 'FirebaseAuth', '~> 11.0'
    fb.dependency 'FirebaseFirestore', '~> 11.0'
    fb.dependency 'FirebaseMessaging', '~> 11.0'
  end
end
