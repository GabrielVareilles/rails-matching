class Taste < ApplicationRecord
  belongs_to :user

  def score(taste)
    (
      (1 - (
            (apple - taste.apple).abs +
            (banana - taste.banana).abs +
            (orange - taste.orange).abs +
            (strawberry - taste.strawberry).abs +
            (peach - taste.peach).abs
          ) / 25.0
      ) * 100
    ).round
  end
end
