puts "Clearing database.."
User.destroy_all

puts "Creating users with profile and criterias.."

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
