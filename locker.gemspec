# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "locker/version"

Gem::Specification.new do |s|
  s.name        = "locker"
  s.version     = Locker::VERSION
  s.authors     = ["Nathan Sutton"]
  s.email       = ["nate@zencoder.com"]
  s.summary     = %q{Locker is a locking mechanism for limiting the concurrency of ruby code using the database.}
  s.description = %q{Locker is a locking mechanism for limiting the concurrency of ruby code using the database. It presently only works with PostgreSQL.}

  s.rubyforge_project = "locker"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "activerecord",  "~>3.0"
  s.add_dependency "pg"
  s.add_development_dependency "rspec"
  s.add_development_dependency "autotest"
end
