source "https://rubygems.org"

gem "activerecord", ">=3.2", "<5"

group :development, :test do
  platform :ruby do
    gem "pg"
  end

  platform :jruby do
    gem 'activerecord-jdbcpostgresql-adapter'
  end

  gem "rspec", "~> 3.2.0"
  gem "pry", "~> 0.10.4"
  gem "pry-byebug", "~> 3.4.2"
end
