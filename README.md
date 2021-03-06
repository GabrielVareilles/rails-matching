# MATCHING USERS in Rails

This tutorial will detail how to match users on multiple criterias and how to improve performance with SQL.

## Matching algorithm

Lets say we want to match users on their fruits tastes :apple: :banana: :orange: :strawberry: :peach:.\
Each user taste relative to a fruit will be a number from 0 to 5.

### Example

We made Mary, John and Eddy fill a form with their tastes, and we got the following answers:

| User          | :apple:   | :banana: | :orange: |:strawberry:| :peach:  |
| ------------- |:---------:|:--------:|:--------:|:----------:|:--------:|
| Mary          | 3.1       | 2.2      |1.0       |5.0         |4.3       |
| John          | 1.2       | 4.3      |3.0       |4.4         |5.0       |
| Eddy          | 2.2       | 3.0      |0.2       |1.3         |3.4       |

What could be the match percentage between Mary and John ?

Answer is simple enough to be part of Fullstack ruby challenges.\
We will take **distances** between each particular tastes, add them together and divide by the **maximum total distance**.

```
The apple distance between Mary and John is 1.9 (3.1 - 1.2).

Total distance is (using absolute values):
1.9 + 2.1 + 2.0 + 0.6 + 0.7 = 7.3

We have 5 different tastes (from 0 to 5), so the maximum total distance is 25.

Matching percentage:
(1 - (7.3/25)) * 100 => 70.8 %
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
rails g model Taste apple:float banana:float orange:float strawberry:float peach:float user:references
rails db:migrate
```
Now let's seed our databse with fake users and random tastes.\
So inside seeds.rb:

```ruby
# db/seeds.rb

puts "Clearing database.."
User.destroy_all

puts "Creating users and tastes.."

100.times do |index|
  user = User.create(
    email: "email-#{index}@taste.com",
    password: 'password'
  )
  Taste.create(
    apple:      rand(0.0..5.0).round(1),
    banana:     rand(0.0..5.0).round(1),
    orange:     rand(0.0..5.0).round(1),
    strawberry: rand(0.0..5.0).round(1),
    peach:      rand(0.0..5.0).round(1),
    user:       user
  )
  puts "#{index} users created.." if index % 10 == 0
end

puts "All good"
```
And run `rails db:seed`

## Matching logic in ruby

Let's translate our algorithm into ruby code.

We could use a score method in `Taste` model that calculates the match percentage between two taste instances.\
So our `Taste` model file will look like:

```ruby
# models/taste.rb

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
    ).round(1)
  end
end
```

Now to compare one particular user to all users from database, and retrieve for instance the top ten matches,\
we could use the following method in `User` model:

```ruby
# models/user.rb

class User < ApplicationRecord
  ...
  has_one :taste, dependent: :destroy

  ...

  def matches(top_n)
    User.includes(:taste)                                # dealing with n+1 query..
        .where.not(id: id)                               # all Users except current instance
        .map { |user| [user, taste.score(user.taste)] }  # Will look like [[#<User.....>, 88.2], [#<User.....>, 60.1] ..]
        .sort_by { |pair| - pair[1] }                    # sorting by match percentage DESC
        .first(top_n)                                    # limiting to the n top results
  end

  ...

end
```

Let's crash test it in `rails console`:

Type in : `User.first.matches(10)`

<img src="/app/assets/images/console.png?raw=true" width="1200">

## Improving our algorithm accuracy

One way to improve our algorithm could be to apply an arbitrary penalty when the relative distance on a criterion is greater than 2.\
In the same way we can apply a bonus if distance is equal or lower than 2.

In other words, when over 2, lets multiply distances by 1.5, and by 0.5 otherwise.

### Matching logic in ruby (advanced version)
Our ruby score method would be modified:

```ruby
  def score(other_taste)
    total_distance = [
      (apple - other_taste.apple).abs,
      (banana - other_taste.banana).abs,
      (orange - other_taste.orange).abs,
      (strawberry - other_taste.strawberry).abs,
      (peach - other_taste.peach).abs,
    ].map { |distance| distance > 2 ? distance * 1.5 : distance * 0.5 }
     .sum

    ((1 - (total_distance / 25.0)) * 100).round(1)
  end
```

## Better performance with SQL

Matching a very large number of users together could cause some performance issues.\
The matching percentage calculation is definitely what's costing us the most here.

So we could delegate that calculation to the database with the following query:

```SQL
      WITH taste as (
        SELECT apple, banana, orange, strawberry, peach
        FROM tastes WHERE user_id = 1
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
      SELECT id, email, (1-(dist1+dist2+dist3+dist4+dist5)/25.0)*100 as match_percentage
      FROM distances
      JOIN users ON users.id = distances.user_id
      ORDER BY match_percentage DESC
      LIMIT 10
```
*Query to retrieve the 10 best matches with the user whose id is 1.*

Here SQL queyword `WITH` allow us to create two subqueries named `taste` and `distances`that we can use later in the query.
- `taste` represents current user taste that we filter with `WHERE` keyword.
- `distances` computes individual fruit distances between current user tastes and all other tastes records.
And we use last `SELECT` to compute all matching percentages.

### Testing the query

We can test this query directly on our database using the awesome [blazer gem](https://github.com/ankane/blazer).\
You can also find more infos about this gem in the DB advanced lecture on Kitt.

<img src="/app/assets/images/blazer.png?raw=true" width="1200">

### Usage in user model

It is possible to play SQL queries directly on database using `ActiveRecord::Base.connection.execute(query)`.

```ruby
# models/user.rb

  def matches_with_sql(top_n)
    query = <<-SQL
      WITH taste as (
        SELECT apple, banana, orange, strawberry, peach
        FROM tastes WHERE user_id = '#{id}'
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
      SELECT users.id, email, (1-(dist1+dist2+dist3+dist4+dist5)/25.0)*100 as match_percentage
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

### Advanced query
The SQL query for the advanced version should be slightly :fearful: modified using `CASE` `WHEN` statements.

```ruby
# models/user.rb

  def matches_with_sql(top_n)
    query = <<-SQL
      WITH taste as (
        SELECT apple, banana, orange, strawberry, peach
        FROM tastes WHERE user_id = '#{id}'
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
      SELECT users.id, email, (1-(dist1+dist2+dist3+dist4+dist5)/25.0)*100 as match_percentage
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

Using [Benchmark module from ruby](https://ruby-doc.org/stdlib-2.5.0/libdoc/benchmark/rdoc/Benchmark.html)\
We can compare the time taken by plain ruby matching and sql.\
Test is made with 5000 users.

Let's code a class method in our User model:

```ruby
# models/user.rb

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

## Going further

- This algorithm can work with many **more criteria** but indeed the code will grow accordingly.

- Applying **weigths** to our different criteria can also be done quite easily if necessary.

- Last but not least we're not tied to match records from the same table, we can use **[polymorphism](https://culttt.com/2016/01/13/creating-polymorphic-relationships-in-ruby-on-rails/?utm_source=lewagon.com)**.
   <img src="/app/assets/images/schema-2.png?raw=true" width="400">
   
*For instance, we could have tried to match users and fruit salads*





Happy fruits (or any other more relevant criteria) matching ! :tada:
