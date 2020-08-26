$LOAD_PATH.push File.expand_path("lib", __dir__)
require "locker/version"

Gem::Specification.new do |s|
  s.name        = "locker"
  s.version     = Locker::VERSION
  s.authors     = ["Nathan Sutton", "Justin Greer"]
  s.email       = ["nate@zencoder.com", "justin@zencoder.com"]
  s.summary     = 'Locker is a locking mechanism for limiting the concurrency of ruby code using the database.'
  s.description = 'Locker is a locking mechanism for limiting the concurrency of ruby code using the database. It presently only works with PostgreSQL.'

  s.rubyforge_project = "locker"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency "activerecord", ">=3.2", "< 6"
  s.add_development_dependency "pg", "~> 0", "< 1"
  s.add_development_dependency "pry", "~> 0.10.4"
  s.add_development_dependency "pry-byebug", "~> 3.4.2"
  s.add_development_dependency "rspec", "~> 3.2"
end
