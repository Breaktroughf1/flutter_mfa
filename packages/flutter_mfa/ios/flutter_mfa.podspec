#
# CocoaPods spec for flutter_mfa. Swift Package Manager (ios/flutter_mfa/Package.swift)
# is the primary integration; this podspec keeps CocoaPods-based apps working.
# Validate with `pod lib lint flutter_mfa.podspec` before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_mfa'
  s.version          = '0.1.0-dev.1'
  s.summary          = 'Secure vault for the flutter_mfa multi-factor authentication plugin.'
  s.description      = <<-DESC
iOS implementation of flutter_mfa: Keychain storage (ThisDeviceOnly, never synced),
optional Secure Enclave envelope and biometric-bound access control.
                       DESC
  s.homepage         = 'https://github.com/Breaktroughf1/flutter_mfa'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'BreaktroughF1 LLP' => 'security@breaktroughf1.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_mfa/Sources/flutter_mfa/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.9'
  s.resource_bundles = { 'flutter_mfa_privacy' => ['flutter_mfa/Sources/flutter_mfa/PrivacyInfo.xcprivacy'] }
end
