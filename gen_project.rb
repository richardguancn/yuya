#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'

# Both Xcode and Swift Package Manager use the same Swift and C sources.
proj_path = File.expand_path('Yuya.xcodeproj', __dir__)
project = File.exist?(proj_path) ? Xcodeproj::Project.open(proj_path) : Xcodeproj::Project.new(proj_path)
target = project.targets.find { |item| item.name == 'Yuya' } || project.new_target(:application, 'Yuya', :osx, '14.0')
group = project.main_group.groups.find { |item| item.path == 'Yuya' } || project.new_group('Yuya', 'Yuya')
%w[AppIcon.swift AppCopy.swift FileAccess.swift PrivacyView.swift YuyaApp.swift ContentView.swift ArchiveViewModel.swift ArchiveService.swift].each do |file|
  ref = group.files.find { |item| item.path == file } || group.new_reference(file)
  target.add_file_references([ref]) unless target.source_build_phase.files_references.include?(ref)
end
bridge = project.main_group.groups.find { |item| item.path == 'Sources/CArchive' } || project.new_group('CArchive', 'Sources/CArchive')
ref = bridge.files.find { |item| item.path == 'CArchive.c' } || bridge.new_reference('CArchive.c')
target.add_file_references([ref]) unless target.source_build_phase.files_references.include?(ref)
legacy_assets = project.main_group.groups.find { |item| item.path == 'assets' }
legacy_assets&.files&.select { |item| %w[Yuya.icns YuyaClownfish.icns].include?(item.path) }&.each(&:remove_from_project)
resources = group.groups.find { |item| item.path == 'Resources' }
resources&.files&.select { |item| item.path == 'YuyaClownfish.icns' }&.each(&:remove_from_project)
assets = project.main_group.groups.find { |item| item.path == 'assets' } || project.new_group('assets', 'assets')
icon = assets.files.find { |item| item.path == 'YuyaIcon.icon' } || assets.new_reference('YuyaIcon.icon')
icon.last_known_file_type = 'folder.iconcomposer.icon'
target.resources_build_phase.add_file_reference(icon) unless target.resources_build_phase.files_references.include?(icon)
privacy = group.files.find { |item| item.path == 'PrivacyInfo.xcprivacy' } || group.new_reference('PrivacyInfo.xcprivacy')
target.resources_build_phase.add_file_reference(privacy) unless target.resources_build_phase.files_references.include?(privacy)
group.new_reference('Yuya.entitlements') unless group.files.any? { |item| item.path == 'Yuya.entitlements' }
target.build_configurations.each do |config|
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'YuyaIcon'
  config.build_settings.delete('ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME')
  config.build_settings.merge!({
    'PRODUCT_NAME' => 'Yuya',
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.gdy.yuya',
    'SWIFT_VERSION' => '6.0',
    'MACOSX_DEPLOYMENT_TARGET' => '14.0',
    'INFOPLIST_FILE' => 'Yuya/Info.plist',
    'CODE_SIGN_STYLE' => 'Automatic',
    'CODE_SIGN_IDENTITY' => '-',
    'CODE_SIGN_ENTITLEMENTS' => 'Yuya/Yuya.entitlements',
    'ENABLE_APP_SANDBOX' => 'YES',
    'ENABLE_HARDENED_RUNTIME' => 'YES',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(SRCROOT)/Sources/CArchive/include',
    'HEADER_SEARCH_PATHS' => '$(inherited) $(SRCROOT)/Sources/CArchive/include',
    'OTHER_LDFLAGS' => '$(inherited) -larchive',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/../Frameworks',
  })
end
# Keep the distributable archive separate from the locally signed DMG build.
project.add_build_configuration('AppStore', :release) unless project.build_configurations.any? { |c| c.name == 'AppStore' }
store = target.add_build_configuration('AppStore', :release)
store.build_settings = target.build_configurations.find { |c| c.name == 'Release' }.build_settings.dup
store.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
store.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
store.build_settings['ARCHS'] = '$(ARCHS_STANDARD)'
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.launch_action.build_configuration = 'Debug'
scheme.archive_action.build_configuration = 'AppStore'
scheme.save_as(proj_path, 'Yuya', true)
project.save
puts "Updated #{proj_path}"
