# Uncomment the next line to define a global platform for your project
platform :osx, '10.14'

target 'Vimac' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for ViMac-Swift

  pod 'AXSwift', '~> 0.2'
  pod 'RxSwift', '~> 5'
  pod 'RxCocoa', '~> 5'
  pod 'MASShortcut'
  pod 'Sparkle'
  pod 'Preferences'

  target 'VimacTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'VimacUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.14'
      if config.name == 'Release'
        config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
        config.build_settings['CODE_SIGN_IDENTITY'] = 'Developer ID Application'
        config.build_settings['DEVELOPMENT_TEAM'] = '5RV873WV4N'
      end
    end
  end
end
