#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'
require 'fileutils'

root = File.expand_path('..', __dir__)
project_path = File.join(root, 'ChemVaultMailApple.xcodeproj')
app_name = 'ChemVaultMailApple'
mac_target_name = 'ChemVaultMailAppleMac'
tests_name = 'ChemVaultMailAppleTests'

FileUtils.rm_rf(project_path)
project = Xcodeproj::Project.new(project_path)
project.root_object.attributes['LastSwiftUpdateCheck'] = '2640'
project.root_object.attributes['LastUpgradeCheck'] = '2640'

app_group = project.main_group.new_group(app_name, app_name)
tests_group = project.main_group.new_group(tests_name, tests_name)

ios_target = project.new_target(:application, app_name, :ios, '17.0')
mac_target = project.new_target(:application, mac_target_name, :osx, '14.0')
tests_target = project.new_target(:unit_test_bundle, tests_name, :ios, '17.0')
tests_target.add_dependency(ios_target)

def add_files_to_group(group, base_path, pattern)
  Dir.glob(File.join(base_path, pattern)).sort.map do |path|
    next if File.directory?(path)

    relative = path.sub("#{base_path}/", '')
    group.new_file(relative)
  end.compact
end

source_refs = add_files_to_group(app_group, File.join(root, app_name), '**/*.{swift,plist}')
swift_source_refs = source_refs.select { |ref| ref.path.end_with?('.swift') }

swift_source_refs.each do |ref|
  ios_target.add_file_references([ref])
  mac_target.add_file_references([ref])
end

test_refs = add_files_to_group(tests_group, File.join(root, tests_name), '**/*.swift')
test_refs.each do |ref|
  tests_target.add_file_references([ref])
end

[ios_target, mac_target].each do |target|
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings['ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS'] = 'YES'
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['CURRENT_PROJECT_VERSION'] = '1'
    settings['DEVELOPMENT_ASSET_PATHS'] = ''
    settings['ENABLE_PREVIEWS'] = 'YES'
    settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'ChemVault Mail'
    settings['INFOPLIST_KEY_LSApplicationCategoryType'] = 'public.app-category.productivity'
    settings['MARKETING_VERSION'] = '0.1'
    settings['PRODUCT_MODULE_NAME'] = app_name
    settings['PRODUCT_NAME'] = 'ChemVault Mail'
    settings['SWIFT_VERSION'] = '6.0'
  end
end

ios_target.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'science.chemvault.mail.apple'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
  settings['SDKROOT'] = 'iphoneos'
end

mac_target.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'science.chemvault.mail.mac'
  settings['SDKROOT'] = 'macosx'
  settings['SUPPORTED_PLATFORMS'] = 'macosx'
  settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
end

tests_target.build_configurations.each do |config|
  settings = config.build_settings
  settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'science.chemvault.mail.apple.tests'
  settings['PRODUCT_MODULE_NAME'] = tests_name
  settings['SDKROOT'] = 'iphoneos'
  settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
  settings['SWIFT_VERSION'] = '6.0'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/ChemVault Mail.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/ChemVault Mail'
end

project.build_configurations.each do |config|
  settings = config.build_settings
  settings['CLANG_ANALYZER_NONNULL'] = 'YES'
  settings['CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION'] = 'YES_AGGRESSIVE'
  settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'gnu++20'
  settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'YES'
  settings['SWIFT_VERSION'] = '6.0'
end

ios_scheme = Xcodeproj::XCScheme.new
ios_scheme.add_build_target(ios_target)
ios_scheme.set_launch_target(ios_target)
ios_scheme.add_test_target(tests_target)
ios_scheme.save_as(project_path, app_name, true)

mac_scheme = Xcodeproj::XCScheme.new
mac_scheme.add_build_target(mac_target)
mac_scheme.set_launch_target(mac_target)
mac_scheme.save_as(project_path, mac_target_name, true)

project.save
