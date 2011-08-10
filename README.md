# Locker

Locker is a locking mechanism for limiting the concurrency of ruby code using the database. It presently only works with PostgreSQL.

In its simplest form it can be used as follows:


```ruby
Locker.run("unique-key") do
  # Code that only one process should be running
end
```
