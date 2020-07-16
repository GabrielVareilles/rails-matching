# MATCHING USERS in Rails

This tutorial will detail how to match users on multiple criterias.\
Lets say we want to match users on their fruits tastes :apple: :banana: :orange: :strawberry: :peach:

Each user taste relative to a fruit will be from 0 to 5.

## Rails template
Lets start with a [devise template](https://github.com/lewagon/rails-templates):

```
rails new \
  -T --database postgresql \
  -m https://raw.githubusercontent.com/lewagon/rails-templates/master/devise.rb \
  rails-matching
```

## Database, Schema and Seeds

Lets create a `Taste` model that will store fruits taste information.
With a `1::N` relation between `User` and `Taste`:

```ruby
rails g model Taste apple:integer banana:integer orange:interger strawberry:integer peach:integer user:references
```

<img src="/app/assets/images/schema.png?raw=true" width="400">

Now lets create some fake users with random tastes, and we want a lot of them !
So inside seeds.rb:

(Warning depending on your machine this could take a while ! ~ 5 to 10 min)

```ruby
puts "Clearing database.."
User.destroy_all

puts "Creating users and tastes.."

5000.times do |index|
  user = User.create(
    email: "email-#{index}@taste.com",
    password: 'password'
  )
  Taste.create(
    apple:      rand(0..5),
    banana:     rand(0..5),
    orange:     rand(0..5),
    strawberry: rand(0..5),
    peach:      rand(0..5),
    user:       user
  )
end

puts "All good"
```

## Matching logic

Now how do we do to compare two user tastes ?
Lets say we have Marie and John that filled a form with:

Marie: :apple: 3 | :banana: 2 | :orange: 1 | :strawberry: 5 | :peach: 4

John:  :apple: 1 | :banana: 4 | :orange: 3 | :strawberry: 4 | :peach: 5

We will take `distances` between each particular tastes using absolute values, add them together and divide by the maximum distance.
For instance here the :apple: distance between Marie and Paul is 2. 
As distance has to be a positive value, we use absolute values.

So the total distance is: 2 + 2 + 2 + 1 + 1 = 8
Matching percentage will now be: (1 - (8/25)) * 100 => 68%

Translated into ruby code we could have a method called score in `Taste` model that calculate the match percentage between two taste instances.
So our Taste model file will look like:

```ruby
#taste.rb

class Taste < ApplicationRecord
  belongs_to :user

  def score(other_taste)
    (
      (1 - (
            (apple - other_taste.apple).abs +
            (banana - other_taste.banana).abs +
            (orange - other_taste.orange).abs +
            (strawberry - other_taste.strawberry).abs +
            (peach - other_taste.peach).abs
          ) / 25.0
      ) * 100
    ).round
  end
end
```

Now to compare one particular user to all users from database we could use the following method in User model:

```ruby
#user.rb
class User < ApplicationRecord
  ...
  has_one :taste, dependent: :destroy

  ...

  def matches(top_n)
    User.includes(:taste)                                # dealing with n+1 query..
        .where.not(id: id)                               # all Users except current instance
        .map { |user| [user, taste.score(user.taste)] }  # Will look like [ [#<User.....>, 88], [#<User.....>, 60], .... ]
        .sort_by { |pair| - pair[1] }                    # sorting by match percentage DESC
        .first(top_n)                                    # limiting to the n top results
  end
  
  ...

end  
```

Lets play a little in console trying to retrieve top 10 matches for the first user:

<img src="/app/assets/images/console-1.png?raw=true" width="800">
<img src="/app/assets/images/console-2.png?raw=true" width="800">

## Better performance with SQL

Now match calculation is made in pure ruby and this could cause performance issues when matching a growing number of users together.

We could delegate this calculation to postgresql doing something like:

```ruby
#user.rb

  def matches_with_sql(top_n)
    query = <<-SQL
      WITH taste as (
        SELECT apple, banana, orange, strawberry, peach
        FROM tastes WHERE user_id = '#{id}'
        ORDER BY id DESC LIMIT 1
      )
      , distances as (
        SELECT
          tastes.user_id,
          ABS(taste.apple - tastes.apple) as dist1,
          ABS(taste.banana - tastes.banana) as dist2,
          ABS(taste.orange - tastes.orange) as dist3,
          ABS(taste.strawberry - tastes.strawberry) as dist4,
          ABS(taste.peach - tastes.peach) as dist5
        FROM taste, tastes
        WHERE tastes.user_id != '#{id}'
      )
      SELECT id, email, CAST((1-(dist1+dist2+dist3+dist4+dist5)/25.0)*100 AS float) as match_percentage
      FROM distances
      JOIN users ON users.id = distances.user_id
      ORDER BY match_percentage DESC
      LIMIT '#{top_n}'
    SQL

    ActiveRecord::Base.connection.execute(query)
                      .to_a
                      .map { |attr| [User.new(attr.except("match_percentage")), attr["match_percentage"]] }
  end
```

## Improving algorithm accuracy

A way to improve our matching algorithm would be for instance to apply penalty when distance between two tastes is over 2 and decrease distance when it is equal or under 2.
In other words lets multiply by 1.5 distances when over 2, and by 0.5 otherwise. 
Our ruby score method would be changed with:

```ruby
  def score(other_taste)
    apple_distance = (apple - other_taste.apple).abs
    banana_distance = (banana - other_taste.banana).abs
    orange_distance = (orange - other_taste.orange).abs
    strawberry_distance = (strawberry - other_taste.strawberry).abs
    peach_distance = (peach - other_taste.peach).abs

    apple_distance *= 0.50 if apple_distance <= 2
    apple_distance *= 1.50 if apple_distance > 2

    banana_distance *= 0.50 if banana_distance <= 2
    banana_distance *= 1.50 if banana_distance > 2

    orange_distance *= 0.50 if orange_distance <= 2
    orange_distance *= 1.50 if orange_distance > 2

    strawberry_distance *= 0.50 if strawberry_distance <= 2
    strawberry_distance *= 1.50 if strawberry_distance > 2

    peach_distance *= 0.50 if peach_distance <= 2
    peach_distance *= 1.50 if peach_distance > 2

    (
      (1 - (
            apple_distance +
            banana_distance +
            orange_distance +
            strawberry_distance.abs +
            peach_distance.abs
          ) / 25.0
      ) * 100
    ).round
  end
```

And the SQL version should be slightly modified (:fearful:)

```ruby
  def matches_with_sql(top_n)
    query = <<-SQL
      WITH taste as (
        SELECT apple, banana, orange, strawberry, peach
        FROM tastes WHERE user_id = '#{id}'
        ORDER BY id DESC LIMIT 1
      )
      , distances as (
        SELECT
          tastes.user_id,
          CASE
            WHEN ABS(taste.apple - tastes.apple) <= 2 THEN (ABS(taste.apple - tastes.apple)*0.50)
            WHEN ABS(taste.apple - tastes.apple) > 2 THEN (ABS(taste.apple - tastes.apple)*1.50)
          END as dist1,
          CASE
            WHEN ABS(taste.banana - tastes.banana) <= 2 THEN (ABS(taste.banana - tastes.banana)*0.50)
            WHEN ABS(taste.banana - tastes.banana) > 2 THEN (ABS(taste.banana - tastes.banana)*1.50)
          END as dist2,
          CASE
            WHEN ABS(taste.orange - tastes.orange) <= 2 THEN (ABS(taste.orange - tastes.orange)*0.50)
            WHEN ABS(taste.orange - tastes.orange) > 2 THEN (ABS(taste.orange - tastes.orange)*1.50)
          END as dist3,
          CASE
            WHEN ABS(taste.strawberry - tastes.strawberry) <= 2 THEN (ABS(taste.strawberry - tastes.strawberry)*0.50)
            WHEN ABS(taste.strawberry - tastes.strawberry) > 2 THEN (ABS(taste.strawberry - tastes.strawberry)*1.50)
          END as dist4,
          CASE
            WHEN ABS(taste.peach - tastes.peach) <= 2 THEN (ABS(taste.peach - tastes.peach)*0.50)
            WHEN ABS(taste.peach - tastes.peach) > 2 THEN (ABS(taste.peach - tastes.peach)*1.50)
          END as dist5
        FROM taste, tastes
        WHERE tastes.user_id != '#{id}'
      )
      SELECT id, email, CAST((1-(dist1+dist2+dist3+dist4+dist5)/25.0)*100 AS float) as match_percentage
      FROM distances
      JOIN users ON users.id = distances.user_id
      ORDER BY match_percentage DESC
      LIMIT '#{top_n}'
    SQL

    ActiveRecord::Base.connection.execute(query)
                      .to_a
                      .map { |attr| [User.new(attr.except("match_percentage")), attr["match_percentage"]] }
  end
```

## Performance Benchmark

Using [Benchmark module from ruby](https://ruby-doc.org/stdlib-2.5.0/libdoc/benchmark/rdoc/Benchmark.html)
we can compare the time taken by plain activerecord matching and pure sql.

Lets code a class method in our User model:

```ruby
  def self.test_performance
    Benchmark.bm do |x|
      x.report { first.matches(10) }
      x.report { first.matches_with_sql(10) }
    end
  end
```

Running this method in rails console gives us the following results:

```
[#<Benchmark::Tms:0x00007fd52a973180
  @label="matching_with_ruby:",
  @real=0.49463400058448315 ...>,
 #<Benchmark::Tms:0x00007fd52a960fd0
  @cstime=0.0,
  @cutime=0.0,
  @label="matching_with_sql:",
  @real=0.017291000112891197 ..>]
```
So using our SQL query reduced the time from 494 ms to 17 ms (for 5k users!! :tada::tada:) 
