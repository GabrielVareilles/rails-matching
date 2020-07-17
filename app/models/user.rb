require 'benchmark'

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one :taste, dependent: :destroy

  def matches(top_n)
    User.includes(:taste)                                # dealing with n+1 query..
        .where.not(id: id)                               # all Users except current instance
        .map { |user| [user, taste.score(user.taste)] }  # Will look like [ [#<User.....>, 88], [#<User.....>, 60], .... ]
        .sort_by { |pair| - pair[1] }                    # sorting by match percentage DESC
        .first(top_n)                                    # limiting to the n top results
  end

  # More accurate version
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
      SELECT users.id, email, CAST((1-(dist1+dist2+dist3+dist4+dist5)/25.0)*100 AS float) as match_percentage
      FROM distances
      JOIN users ON users.id = distances.user_id
      ORDER BY match_percentage DESC
      LIMIT '#{top_n}'
    SQL

    ActiveRecord::Base.connection.execute(query)
                      .to_a
                      .map { |attr| [User.new(attr.except("match_percentage")), attr["match_percentage"]] }
  end

  # Old version
  # def matches_with_sql(top_n)
  #   query = <<-SQL
  #     WITH taste as (
  #       SELECT apple, banana, orange, strawberry, peach
  #       FROM tastes WHERE user_id = '#{id}'
  #       ORDER BY id DESC LIMIT 1
  #     )
  #     , distances as (
  #       SELECT
  #         tastes.user_id,
  #         ABS(taste.apple - tastes.apple) as dist1,
  #         ABS(taste.banana - tastes.banana) as dist2,
  #         ABS(taste.orange - tastes.orange) as dist3,
  #         ABS(taste.strawberry - tastes.strawberry) as dist4,
  #         ABS(taste.peach - tastes.peach) as dist5
  #       FROM taste, tastes
  #       WHERE tastes.user_id != '#{id}'
  #     )
  #     SELECT id, email, CAST((1-(dist1+dist2+dist3+dist4+dist5)/25.0)*100 AS float) as match_percentage
  #     FROM distances
  #     JOIN users ON users.id = distances.user_id
  #     ORDER BY match_percentage DESC
  #     LIMIT '#{top_n}'
  #   SQL

  #   ActiveRecord::Base.connection.execute(query)
  #                     .to_a
  #                     .map { |attr| [User.new(attr.except("match_percentage")), attr["match_percentage"]] }
  # end

  def self.test_performance
    Benchmark.bm do |x|
      x.report("matching_with_ruby:") { first.matches(10) }
      x.report("matching_with_sql:") { first.matches_with_sql(10) }
    end
  end
end
