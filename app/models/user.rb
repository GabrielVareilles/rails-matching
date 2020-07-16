require 'benchmark'

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one :profile, dependent: :destroy
  has_one :taste, dependent: :destroy

  def matches_n_plus_one
    User.all
        .map { |user| [user, taste.score(user.taste)] }
        .sort_by { |pair| - pair[1] }
  end

  def matches
    User.includes(:taste)
        .all
        .map { |user| [user, taste.score(user.taste)] }
        .sort_by { |pair| - pair[1] }
  end

  def matches_with_sql
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
    SQL

    ActiveRecord::Base.connection.execute(query)
                      .to_a
                      .map { |attr| [User.new(attr.except("match_percentage")), attr["match_percentage"]] }
  end

  def self.test_performance
    Benchmark.bm do |x|
      x.report { first.matches_n_plus_one }
      x.report { first.matches }
      x.report { first.matches_with_sql }
    end
  end
end
