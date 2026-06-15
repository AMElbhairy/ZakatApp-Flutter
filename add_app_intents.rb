require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Runner target
target = project.targets.find { |t| t.name == 'Runner' }
app_intents_dir = 'Runner/AppIntents'
group = project.main_group.find_subpath('Runner', true)
app_intents_group = group.children.find { |c| c.name == 'AppIntents' } || group.new_group('AppIntents', 'AppIntents')

['LogBankMessageIntent.swift', 'ZakahWealthShortcutsProvider.swift'].each do |file|
  file_path = File.join(app_intents_dir, file)
  unless app_intents_group.files.any? { |f| f.path == file }
    file_ref = app_intents_group.new_file(file)
    target.add_file_references([file_ref])
    puts "Added #{file} to Xcode project."
  else
    puts "#{file} already in Xcode project."
  end
end

project.save
