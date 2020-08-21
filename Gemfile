source "https://rubygems.org"

gem "activerecord", ">=4.2", "<6"

group :development, :test do
  platform :ruby do
    gem "pg", "~> 0.21.0", "< 1.0"
    gem "pry", "~> 0.13.1"
    gem "pry-byebug", "~> 3.9.0"
  end

  platform :jruby do
    gem 'activerecord-jdbcpostgresql-adapter', "~> 50"
  end

  gem "rspec", "~> 3.9.0"
end
