Pod::Spec.new do |s|
  s.name             = 'instagram_share_plus'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for sharing photos and videos to Instagram.'
  s.description      = <<-DESC
A Flutter plugin that enables sharing photos and videos to Instagram from a Flutter application.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Name' => 'your.email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'
  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
