Pod::Spec.new do |s|
  s.name           = 'BookshelfARNative'
  s.version        = '1.0.0'
  s.summary        = 'Local ARKit shelf mapping for Bookshelf AR Catalog.'
  s.description    = 'An Expo native module that persists ARKit world maps and renders book markers with RealityKit.'
  s.license        = { type: 'MIT' }
  s.author         = { 'Bookshelf AR Catalog' => 'support@example.invalid' }
  s.homepage        = 'https://expo.dev'
  s.platforms       = { ios: '15.1' }
  s.source          = { git: 'https://github.com/expo/expo.git' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'
  s.frameworks = 'ARKit', 'RealityKit'
  s.source_files = '**/*.{h,m,mm,swift}'
end