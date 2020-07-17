# MATCHING USERS in Rails

This tutorial will detail how to match users on multiple criterias.


## Matching algorithm 

Lets say we want to match users on their fruits tastes :apple: :banana: :orange: :strawberry: :peach:.\
Each user taste relative to a fruit will be an integer from 0 to 5.

### Example

We made Marie, John and Eddy fill a form with their tastes, and we got the following answers:

| User          | :apple:   | :banana: | :orange: |:strawberry:| :peach:  |
| ------------- |:---------:|:--------:|:--------:|:----------:|:--------:|
| Mary         | 3         | 2        |1         |5           |4         |
| John          | 1         | 4        |3         |4           |5         |
| Eddy          | 2         | 3        |0         |1           |3         |

What could be the match percentage between Mary and John ?

Answer is simple enough to be part of Fullstack ruby challenges.
We will take **distances** between each particular tastes, add them together and divide by the **maximum total distance**.

```
The apple distance between Mary and John is 2 (3 - 1).
As distances have to be positive values, we use absolute values.

So the total distance between Mary and John is: 
2 + 2 + 2 + 1 + 1 = 8

Since we have 5 different tastes (from 0 to 5) the maximum total distance is 25.
 
 Matching percentage:
(1 - (8/25)) * 100 => 68 %
```

Time to code !

## Rails template
Lets start with a [devise template](https://github.com/lewagon/rails-templates):

```
rails new \
  -T --database postgresql \
  -m https://raw.githubusercontent.com/lewagon/rails-templates/master/devise.rb \
  rails-matching
```
## Schema

<img src="/app/assets/images/schema.png?raw=true" width="400">

## Models and Seeds

Create a `Taste` model that will store fruits taste information:

```ruby
rails g model Taste apple:integer banana:integer orange:interger strawberry:integer peach:integer user:references
rails db:migrate
```
Now let's seed our databse with fake users and random tastes, and we want a lot of them !
So inside seeds.rb:

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
  puts "#{index} users created.." if index % 100 == 0
end

puts "All good"
```
And run `rails db:seed`

(Warning depending on your machine this could take a while ! ~ 5 to 10 min => :coffee: or feel free to change 5000 to any other smaller number)

## Matching logic in ruby

Let's translate our algorithm into ruby code.

We could use a score method in `Taste` model that calculates the match percentage between two taste instances.
So our `Taste` model file will look like:

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

Now to compare one particular user to all users from database, and retrieve for instance the top ten matches we could use the following method in `User` model:

```ruby
#user.rb
class User < ApplicationRecord
  ...
  has_one :taste, dependent: :destroy

  ...

  def matches(top_n)
    User.includes(:taste)                                # Dealing with n+1 query..
        .where.not(id: id)                               # All Users except current instance
        .map { |user| [user, taste.score(user.taste)] }  # Will look like [ [#<User.....>, 88], [#<User.....>, 60], .... ]
        .sort_by { |pair| - pair[1] }                    # Sorting by match percentage DESC
        .first(top_n)                                    # Limiting to the n top results
  end
  
  ...

end  
```

Let's crash test it in `rails console`:

Type in : `User.first.matches(10)`

<img src="/app/assets/images/console-2.png?raw=true" width="1200">

## Better performance with SQL

Matching a very large number of users together could cause some performance issues.

### Query
We could delegate this calculation to the database with the following query:

```SQL
      WITH taste as (
        SELECT apple, banana, orange, strawberry, peach
        FROM tastes WHERE user_id = 1
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
        WHERE tastes.user_id != 1
      )
      SELECT id, email, CAST((1-(dist1+dist2+dist3+dist4+dist5)/25.0)*100 AS float) as match_percentage
      FROM distances
      JOIN users ON users.id = distances.user_id
      ORDER BY match_percentage DESC
      LIMIT 10
```
*Query to retrieve the 10 best matches with the user whose id is 1.*

#### A little explanation may be required

Here SQL queyword `WITH` allow us to create two subqueries named `taste` and `distances`that we can use later in the query.
- `taste` represents current user taste that we filter with `WHERE` keyword.
- `distances` computes individual fruit distances between current user tastes and all other tastes records.
And we use last `SELECT` to compute all matching percentages.

### Usage in user model

It is possible to play SQL queries directly on database using `ActiveRecord::Base.connection.execute(query)`.

```ruby
#user.rb
'
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
                      .map { |result| [User.new(result.except("match_percentage")), result["match_percentage"]] }
  end
```

We can compute the same result as before using results from the database.

## Improving our algorithm accuracy

One way to improve our algorithm could be to apply an arbitrary penalty when the relative distance on a criterion is greater than 2.
In the same way we can apply a bonus if distance is equal or lower than 2.

In other words, when over 2, lets multiply distances by 1.5, and by 0.5 otherwise.

### Ruby
Our ruby score method would be modified:

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

### SQL
And the SQL version should be slightly modified using `CASE` `WHEN` statements :fearful:

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
We can compare the time taken by plain ruby matching and sql.

Let's code a class method in our User model:

```ruby
  def self.test_performance
    Benchmark.bm do |x|
      x.report("matching_with_ruby:") { first.matches(10) }
      x.report("matching_with_sql:") { first.matches_with_sql(10) }
    end
  end
```

Running this method in `rails console gives` us the following results:

```
                          user       system      total       real
matching_with_ruby:      0.340416   0.005283   0.345700 (  0.366541)                                                          
matching_with_sql:       0.001510   0.000200   0.001710 (  0.016998)
```
SQL query reduced the time from **366 ms** to **17 ms**,  => ~ **20 times faster** :muscle:

Happy fruits (or any other more relevant criteria) matching ! :tada: :tada: 
