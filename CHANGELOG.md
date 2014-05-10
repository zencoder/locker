# Changelog

## 0.2.0

[Full Changelog](http://github.com/zencoder/locker/compare/v0.1.0...v0.2.0)

Enhancements:

* Added the ability to use Postgres advisory locks via Locker::Advisory.

## 0.1.0

[Full Changelog](http://github.com/zencoder/locker/compare/v0.0.3...v0.1.0)

**NOTE:** You will need to manually add the `sequence` column. See the README for more information.

Enhancements:

* Added a `sequence` column that gets incremented when a lock is acquired. The value of sequence is then passed into the lock block.
* Added multi-ruby testing using Travis CI. Tests passes in just about everything.
* Now supports MRI 1.8.7+, rbx, and jruby.

Bugfixes:

* Removed weirdness around defaulting to using ActiveSupport::SecureRandom when SecureRandom was missing, which should have never been the case.
