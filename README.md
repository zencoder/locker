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

Well, lets say you have a process running on a server that continually performs a task:

### Server 1

#### Code (lib/new_feed_checker.rb)

```ruby
while true
  FeedChecker.check_for_new_feeds
end
```

#### Run

`script/rails runner lib/new_feed_checker.rb`

This is great if you only have one server, or if you don't care about the process stopping if the server it's running on goes down. If you wanted to make this more fault tolerant, you might add another server performing the same task:

### Server 2

*Same as Server 1*

This would work fantastic, so long as `FeedChecker.check_for_new_feeds` is safe to run simultaneously on two servers. If it's not safe to run simultaneously, you need to either make it safe or make sure only one server runs the code at any given time. This is where Locker comes in. Lets change the code to take advantage of Locker.

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

#### Run

`script/rails runner lib/new_feed_checker.rb`

When we run this on both servers only one server will obtain the lock and run `FeedChecker.check_for_new_feeds`. The other server will simply skip the block entirely. Only the server that obtains the lock will run the code, and only one server can obtain the lock at any one time. The first server to get to the lock wins! After the server that obtained the lock finishes running the code the lock will be released.

This is great, we've made sure that only one server can run the code at any given time. But wait! Since the server that didn't obtain the lock just skips it and finishes running, we still can't handle one of the servers going down. If only we could wait for the lock to become available instead of skipping the block. Good news, we can!

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

#### Run

`script/rails runner lib/new_feed_checker.rb`

The addition of `:blocking => true` means that whichever server doesn't obtain the lock at first will just wait and keep trying to get the lock. If the server that obtains the lock goes down at any point, the second server will automatically take over. In this way we've made it so that we don't need to make the code handle concurrency while making sure that the code stays running even if a server goes down.

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

If you're using Rails 2.3.x, well, I couldn't be arsed to figure out generators for it, so you'll need to create the migration and the model yourself:

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

## Common pattern

In our use we've settled on a common pattern, one that lets us distribute the load of our processes between our application or utility servers while making sure we have no single point of failure, no single server going down (except, maybe, the database) will stop the code from executing. Continuing from the example above, we'll make sure the `FeedChecker.check_for_new_feeds` rotates among our servers.

```ruby
while true
  Locker.run("new-feed-checker", :blocking => true) do
    FeedChecker.check_for_new_feeds
  end
  sleep(Kernel.rand + 1) # Delay the next try so that the other servers will have a chance to obtain the lock
end
```

Instead of first server having a monopoly on the lock, each server will obtain a lock only for the duration of the call to `FeedChecker.check_for_new_feeds`. We introduce a random delay so that other servers will have a chance to obtain the lock. If we didn't add that delay then after the first server finished running the FeedChecker it would immediately re-obtain the lock. This is due to how the 'blocking' mechanism works. The blocking mechanism will try to obtain the lock then sleep for half a second, repeating continually until the lock is obtained. The random delay, therefore, will make sure that another server will obtain the lock before the first server will attempt to obtain it again (since 1.Xs > 0.5s), while also randomizing the chances of the first server obtaining locks in the future. In effect this will make sure that over a long enough time period each server will have obtained an equal number of locks. A side benefit of this pattern is that if you don't need the code run constantly you could introduce a much larger sleep and random value.
