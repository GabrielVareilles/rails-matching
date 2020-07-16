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

Paul:  :apple: 1 | :banana: 4 | :orange: 3 | :strawberry: 4 | :peach: 5

We will take `distances` between each particular tastes using absolute values, add them together and divide by the maximum distance.
For instance here the :apple: distance between Marie and Paul is 2. 
As distance has to be a positive value, we use absolute values.

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
        .limit(top_n)                                    # limiting to the n top results
  end
  
  ...

end  
```

Lets play a little in console trying to retrieve top 10 matches for the first user:

<img src="/app/assets/images/console-1.png?raw=true" width="800">
<img src="/app/assets/images/console-2.png?raw=true" width="800">



