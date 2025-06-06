# frozen_string_literal: true

require_relative "lib/sunniesnow-convert/version"

Gem::Specification.new do |spec|
  spec.name = "sunniesnow-convert"
  spec.version = Sunniesnow::Convert::VERSION
  spec.authors = ["Ulysses Zhan"]
  spec.email = ["ulysseszhan@gmail.com"]

  spec.summary = "Converter from charts of other rhythm games into Sunniesnow charts"
  spec.homepage = "https://github.com/sunniesnow/sunniesnow-convert"
  spec.license = "AGPL-3.0-or-later"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/sunniesnow/sunniesnow-convert"
  #spec.metadata["changelog_uri"] = ""

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
