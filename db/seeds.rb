household = Household.create!(name: "我們家")
User.create!(household: household, name: "Jerry", email: "jerry@example.com", password: "password123")
User.create!(household: household, name: "Rainy", email: "rainy@example.com", password: "password123")

puts "Seed 完成：Household #{household.name}，2 位成員"
