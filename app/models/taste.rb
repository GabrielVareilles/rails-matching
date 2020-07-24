class Taste < ApplicationRecord
  belongs_to :user

  # More accurate version
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

  # Simple version

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
