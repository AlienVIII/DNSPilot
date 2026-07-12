Pod::Spec.new do |s|
  s.name           = 'DNSPilotRuntime'
  s.version        = '0.1.0'
  s.summary        = 'DNSPilot shared Rust core runtime'
  s.description    = 'Runs DNSPilot core actions inside the mobile app process.'
  s.author         = 'DNSPilot'
  s.homepage       = 'https://example.invalid/dnspilot'
  s.platforms      = { :ios => '16.4' }
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }
  s.source_files = '**/*.swift'
  s.vendored_frameworks = 'native/apple/DNSPilotMobileRuntime.xcframework'
end
