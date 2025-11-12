#!/bin/bash

# Use Xcode's PBXProj tool to safely add resources
# For now, let's use a simple Ruby script that uses xcodeproj gem

cat > add_models.rb << 'RUBY_SCRIPT'
require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the Runner target
target = project.targets.find { |t| t.name == 'Runner' }

# Get the Resources group
resources_group = project.main_group.groups.find { |g| g.name == 'Resources' } || 
                  project.main_group.new_group('Resources')

# Add the model files to the project
files_to_add = [
  'Runner/Resources/face_detection_yunet_2023mar.onnx',
  'Runner/Resources/haarcascade_frontalface_default.xml',
  'Runner/Resources/haarcascade_eye.xml'
]

files_to_add.each do |file_path|
  # Check if file already exists in project
  existing = resources_group.files.find { |f| f.path == file_path }
  next if existing
  
  # Add file reference
  file_ref = resources_group.new_file(file_path)
  
  # Add to Resources build phase
  resources_phase = target.resources_build_phase
  resources_phase.add_file_reference(file_ref)
end

project.save
puts "Successfully added model files to Xcode project"
RUBY_SCRIPT

ruby add_models.rb
