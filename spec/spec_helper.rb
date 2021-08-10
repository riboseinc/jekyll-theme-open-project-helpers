# frozen_string_literal: true

require "bundler/setup"
require "rspec/matchers"
require "rspec-command"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include RSpecCommand
end

class Array
  def stringify_all_keys
    map do |v|
      case v
      when Hash, Array
        v.stringify_all_keys
      else
        v
      end
    end
  end
end

class Hash
  def stringify_all_keys
    result = {}
    each do |k, v|
      result[k.to_s] = case v
                       when Hash, Array
                         v.stringify_all_keys
                       else
                         v
                       end
    end
    result
  end
end
