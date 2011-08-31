# Locker

Locker is a locking mechanism for limiting the concurrency of ruby code using the database. It presently only works with PostgreSQL.

Locker is dependent on the Postgres (pg) and ActiveRecord (>= 2.3.14) gems.

## The Basics

In its simplest form it can be used as follows:

```ruby
Locker.run("unique-key") do
  # Code that only one process should be running
end
```

## What does it do?

Suppose you have a process running on a server that continually performs a task. In our examples we'll use an RSS/Atom feed checker:

### Server 1

#### Code (lib/new_feed_checker.rb)

```ruby
while true
  FeedChecker.check_for_new_feeds
end
```

`script/rails runner lib/new_feed_checker.rb`

This is great if you have only one server, or if you're okay with running the code on only one of your servers and don't care if the server goes down (and thus the code stops running until the server is back up). If you wanted to make this more fault tolerant you might add another server performing the same task:

### Server 2

*Same as Server 1*

This would work fantastic, so long as `FeedChecker.check_for_new_feeds` is safe to run concurrently on two or more servers. If it's not safe to run concurrently, you need to either make it concurrency-safe or make sure only one server runs the code at any given time. This is where Locker comes in. Lets change the code to take advantage of Locker.

### Server 1 and 2

#### Code (lib/new_feed_checker.rb)

```ruby
Locker.run("new-feed-checker") do # One server will get the lock
  # Only one server will get here
  while true
    FeedChecker.check_for_new_feeds
  end
end # Lock is released at this point
```

`script/rails runner lib/new_feed_checker.rb`

When we run this code on both servers, only one server will obtain the lock and run `FeedChecker.check_for_new_feeds`. The other server will simply skip the block entirely. Only the server that obtains the lock will run the code, and only one server can obtain the lock at any given time. The first server to get to the lock wins! After the server that obtained the lock finishes running the code block, the lock will be released.

This is great! We've made sure that only one server can run the code at any given time. But wait! Since the server that didn't obtain the lock just skips the code and finishes running we still can't handle one of the servers going down. If only we could wait for the lock to become available instead of skipping the block. Good news, we can!

### Server 1 and 2

#### Code (lib/new_feed_checker.rb)

```ruby
Locker.run("new-feed-checker", :blocking => true) do
  # Only one server will get here at a time. The other server will patiently wait.
  while true
    FeedChecker.check_for_new_feeds
  end
end # Lock is released at this point
```

`script/rails runner lib/new_feed_checker.rb`

The addition of `:blocking => true` means that whichever server doesn't obtain the lock at first will simply wait and keep trying to get the lock. If the server that first obtains the lock goes down at any point, the second server will automatically take over. By using this technique we've made it so that we don't need to make the code handle concurrency while simultaneously making sure that the code stays running even if a server goes down.

## Installation

If you're using bundler you can add it to your 'Gemfile':

```ruby
gem "locker"
```

Then, of course, `bundle install`.

Otherwise you can just `gem install locker`.

## Setup

This gem includes generators for Rails 3.0+:

```bash
script/rails generate locker [ModelName]
```

The 'ModelName' defaults to 'Lock'. This will generate the Lock model and its migration.

I apologize if you're using Rails 2.3.x, I couldn't be arsed to figure out how to make generators for it and Rails 3.x+, so you'll need to create the migration and the model yourself:

```ruby
class CreateLocks < ActiveRecord::Migration
  def self.up
    create_table :locks do |t|
      t.string :locked_by
      t.string :key
      t.datetime :locked_at
      t.datetime :locked_until
    end

    add_index :locks, :key, :unique => true
  end

  def self.down
    drop_table :locks
  end
end
```

```ruby
class Lock < ActiveRecord::Base
end
```

## Advanced Usage

Locker uses some rather simple methods to accomplish its purpose. These simple methods include obtaining, renewing, and releasing the locks.

```ruby
lock = Locker.new("some-unique-key")
lock.get     # => true  (Lock obtained)
# Do something that doesn't take too long here
lock.renew   # => true  (Lock renewed)
# Do another thing that doesn't take too long here
lock.release # => false (Lock released)
```

The locks consist of records in the `locks` table which have a the following columns: `key`, `locked_by`, `locked_at`, and `locked_until`. The `key` column has uniqueness enforced at the database level to prevent race conditions and duplicate locks. `locked_by` has an identifier unique to the process and object running the code block. This unique identifier makes sure that that we know if we should be able to renew our lock. `locked_at` is a utility column for checking how long a lock has been monopolized. `locked_until` tells us when the lock will expire if it is not renewed.

When Locker is used via the `run` method, an auto-renewer thread is run until the `run` block finishes, at which time the lock is released. By default all locks are obtained for 30 seconds and auto-renewed every 10 seconds. Locks that expire can be taken over by other processes or threads. If your lock expires and another process or thread takes over, Locker will raise `Locker::LockStolen`. The lock duration and time between renewals can be customized.

```ruby
# :lock_for is the lock duration in seconds. Must be greater than 0 and greater than :renew_every
# :renew_every is the time to sleep between renewals in seconds. Must be greater than 0 and less than :lock_for
Locker.run("some-unique-key", :lock_for => 60, :renew_every => 5) do
  # Your code goes here
end
```

If you changed the name of the Lock model, or if you have multiple Lock models, you can customize the model to be used either when you run `Locker.run` or on the Locker class itself.

```ruby
Locker.model = SomeOtherOtherLockModel

Locker.run("some-unique-key") do
  # Locked using SomeOtherOtherLockModel
end

Locker.run("some-unique-key", :model => SomeOtherLockModel) do
  # Locked using SomeOtherLockModel
end
```

## A Common pattern

In our use we've settled on a common pattern, one that lets us distribute the load of our processes between our application and/or utility servers while making sure we have no single point of failure. This means that no single server going down (except the database) will stop the code from executing. Continuing from the code above, we'll use the example of the RSS/Atom feed checker, `FeedChecker.check_for_new_feeds`. To improve on the previous examples, we'll make the code rotate among our servers, so over a long enough time period each server will have spent an equal amount of time running the task.

```ruby
while true
  Locker.run("new-feed-checker", :blocking => true) do
    FeedChecker.check_for_new_feeds
  end
  sleep(Kernel.rand + 1) # Delay the next try so that the other servers will have a chance to obtain the lock
end
```

Instead of the first server to obtain the lock having a monopoly, each server will obtain a lock only for the duration of the call to `FeedChecker.check_for_new_feeds`. We introduce a random delay so that other servers will have a chance to obtain the lock. If we didn't add that delay then after the first server finished running the FeedChecker it would immediately re-obtain the lock. This is due to how the 'blocking' mechanism works. The blocking mechanism will try to obtain the lock then sleep for half a second, repeating continually until the lock is obtained. The random delay, therefore, will make sure that another server will obtain the lock before the first server will attempt to obtain it again (since 1.Xs > 0.5s), while also randomizing the chances of the first server obtaining locks in the future. In effect this will make sure that over a long enough time period each server will have obtained an equal number of locks. A side benefit of this pattern is that if you don't need the code to run constantly you could introduce a much larger sleep and random value.
