class Taste < ApplicationRecord
  belongs_to :user

  # More accurate version
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

  # old version

  # def score(other_taste)
  #   (
  #     (1 - (
  #           (apple - other_taste.apple).abs +
  #           (banana - other_taste.banana).abs +
  #           (orange - other_taste.orange).abs +
  #           (strawberry - other_taste.strawberry).abs +
  #           (peach - other_taste.peach).abs
  #         ) / 25.0
  #     ) * 100
  #   ).round
  # end

end
