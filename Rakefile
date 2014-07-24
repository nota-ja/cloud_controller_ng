$:.unshift(File.expand_path("../lib", __FILE__))
$:.unshift(File.expand_path("../app", __FILE__))

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __FILE__)
require "bundler/setup"

require "yaml"
require "sequel"
require "steno"
require "cloud_controller"

def config
  @config ||= begin
    config_file = ENV["CLOUD_CONTROLLER_NG_CONFIG"] || File.expand_path("../config/cloud_controller.yml", __FILE__)
    config = VCAP::CloudController::Config.from_file(config_file)
    config
  end
end

Dir["lib/tasks/**/*.rake"].each do |tasks|
  load tasks
end

task default: [:rubocop, :spec]

## based on http://r9.hatenablog.jp/entry/2013/06/22/000000
task :routes do
  begin
    VCAP::CloudController::FrontController.class_eval do
      routes = self.instance_variable_get(:@routes)
      routes.each do |verb, signatures|
        next if verb == "HEAD"
        signatures.each do |pattern, keys, conditions, block|
          path = pattern.to_s
          path.sub!(/^\(\?-mix:(\\A)?\\/, '')
          path.sub!(/(\\z)?\)$/, '')
          path.gsub!(/\\\//, '/')
          puts "%-6s\t%s\t%s\t%s\t%s" % [verb, path, keys.inspect, conditions.inspect, block.inspect]
        end
      end
    end
  end
end
