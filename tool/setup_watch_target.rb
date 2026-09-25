require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

runner_target = project.targets.find { |t| t.name == 'Runner' }
raise "Runner target not found" unless runner_target

# 1. Add WatchSessionManager.swift to Runner/WatchBridge
runner_group = project.main_group.find_subpath('Runner', true)
watch_bridge_group = runner_group.children.find { |c| c.name == 'WatchBridge' } || runner_group.new_group('WatchBridge', 'WatchBridge')

manager_file_name = 'WatchSessionManager.swift'
manager_ref = watch_bridge_group.files.find { |f| f.path == manager_file_name }
unless manager_ref
  manager_ref = watch_bridge_group.new_file(manager_file_name)
  runner_target.source_build_phase.add_file_reference(manager_ref)
  puts "Added WatchSessionManager.swift to Runner compile sources."
else
  unless runner_target.source_build_phase.files_references.include?(manager_ref)
    runner_target.source_build_phase.add_file_reference(manager_ref)
    puts "Added existing WatchSessionManager.swift reference to Runner build phase."
  end
end

# 2. Setup ZakahWealthWatchApp Target
watch_target = project.targets.find { |t| t.name == 'ZakahWealthWatchApp' }
unless watch_target
  watch_target = project.new_target(:application, 'ZakahWealthWatchApp', :watchos, '9.0')
  puts "Created ZakahWealthWatchApp target."
else
  puts "ZakahWealthWatchApp target already exists."
end

# Configure build settings
watch_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'ZakahWealthWatchApp'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.zakahwealth.app.watchkitapp'
  config.build_settings['INFOPLIST_FILE'] = 'ZakahWealthWatchApp/Info.plist'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['SDKROOT'] = 'watchos'
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '9.0'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  config.build_settings['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
end

# 3. Populate ZakahWealthWatchApp Group & Files
watch_group = project.main_group.find_subpath('ZakahWealthWatchApp', false) || project.main_group.new_group('ZakahWealthWatchApp', 'ZakahWealthWatchApp')

def add_file_to_phase(group, target, phase, relative_path, file_name)
  subgroup = relative_path.empty? ? group : (group.find_subpath(relative_path, false) || group.new_group(relative_path, relative_path))
  ref = subgroup.files.find { |f| f.path == file_name }
  unless ref
    ref = subgroup.new_file(file_name)
  end
  unless phase.files_references.include?(ref)
    phase.add_file_reference(ref)
  end
  ref
end

sources_phase = watch_target.source_build_phase
resources_phase = watch_target.resources_build_phase

# Swift source files
add_file_to_phase(watch_group, watch_target, sources_phase, '', 'ZakahWealthWatchApp.swift')
add_file_to_phase(watch_group, watch_target, sources_phase, '', 'WatchConnectivityManager.swift')
add_file_to_phase(watch_group, watch_target, sources_phase, 'Models', 'WatchDTOs.swift')
add_file_to_phase(watch_group, watch_target, sources_phase, 'Theme', 'WatchTheme.swift')
add_file_to_phase(watch_group, watch_target, sources_phase, 'Views', 'WatchHomeShellView.swift')
add_file_to_phase(watch_group, watch_target, sources_phase, 'Views', 'WatchInboxView.swift')
add_file_to_phase(watch_group, watch_target, sources_phase, 'Views', 'WatchReviewItemView.swift')
add_file_to_phase(watch_group, watch_target, sources_phase, 'Views', 'WatchPendingResolverView.swift')
add_file_to_phase(watch_group, watch_target, sources_phase, 'Navigation', 'WatchNavigationManager.swift')
add_file_to_phase(watch_group, watch_target, sources_phase, 'Notifications', 'WatchNotificationManager.swift')

# Resources
add_file_to_phase(watch_group, watch_target, resources_phase, '', 'Assets.xcassets')

# Info.plist (non-compiled file reference)
unless watch_group.files.any? { |f| f.path == 'Info.plist' }
  watch_group.new_file('Info.plist')
end

# 4. Target Dependency & Embed Watch Content in Runner
unless runner_target.dependencies.any? { |d| d.target == watch_target }
  runner_target.add_dependency(watch_target)
  puts "Added ZakahWealthWatchApp dependency to Runner."
end

embed_phase = runner_target.copy_files_build_phases.find { |p| p.name == 'Embed Watch Content' }
unless embed_phase
  embed_phase = runner_target.new_copy_files_build_phase('Embed Watch Content')
  embed_phase.dst_subfolder_spec = '16' # Products Directory
  embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
  puts "Created Embed Watch Content build phase in Runner."
end

# Ensure proper ordering before Thin Binary
runner_target.build_phases.delete(embed_phase)
widget_idx = runner_target.build_phases.index { |p| p.display_name == 'Embed Foundation Extensions' }
insert_idx = widget_idx ? widget_idx + 1 : 7
runner_target.build_phases.insert(insert_idx, embed_phase)

unless embed_phase.files_references.include?(watch_target.product_reference)
  build_file = embed_phase.add_file_reference(watch_target.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  puts "Added watch app product to Embed Watch Content phase."
end

project.save
puts "Successfully saved Runner.xcodeproj with ZakahWealthWatchApp target."
