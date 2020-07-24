puts "Clearing database.."
User.destroy_all

puts "Creating users with tastes.."

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
  puts "#{index} user created.." if index % 10 == 0
end

puts "All good"
