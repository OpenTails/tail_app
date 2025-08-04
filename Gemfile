source "https://rubygems.org"

gem "fastlane"
gem "cocoapods"

# https://github.com/fastlane/fastlane/issues/29183
# Until Fastlane includes them directly.
gem "abbrev"
gem "mutex_m"
gem "ostruct"


plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
