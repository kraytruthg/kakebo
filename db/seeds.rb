household = Household.find_or_create_by!(name: "我們家")
User.find_or_create_by!(email: "jerry@example.com") do |u|
  u.household = household
  u.name = "Jerry"
  u.password = "password123"
end
User.find_or_create_by!(email: "rainy@example.com") do |u|
  u.household = household
  u.name = "Rainy"
  u.password = "password123"
end

# 帳戶
Account.find_or_create_by!(household: household, name: "玉山銀行") do |a|
  a.account_type = "budget"
  a.starting_balance = 50_000
  a.balance = 50_000
end
Account.find_or_create_by!(household: household, name: "現金") do |a|
  a.account_type = "budget"
  a.starting_balance = 5_000
  a.balance = 5_000
end

# 類別群組和類別
bills = CategoryGroup.find_or_create_by!(household: household, name: "固定支出", position: 1)
Category.find_or_create_by!(category_group: bills, name: "房租", position: 1)
Category.find_or_create_by!(category_group: bills, name: "電費", position: 2)
Category.find_or_create_by!(category_group: bills, name: "網路費", position: 3)

daily = CategoryGroup.find_or_create_by!(household: household, name: "日常開銷", position: 2)
Category.find_or_create_by!(category_group: daily, name: "餐費", position: 1)
Category.find_or_create_by!(category_group: daily, name: "日用品", position: 2)
Category.find_or_create_by!(category_group: daily, name: "交通", position: 3)

savings = CategoryGroup.find_or_create_by!(household: household, name: "儲蓄目標", position: 3)
Category.find_or_create_by!(category_group: savings, name: "旅遊基金", position: 1)
Category.find_or_create_by!(category_group: savings, name: "緊急備用金", position: 2)

# 當月的 BudgetEntry
current_year, current_month = Date.today.year, Date.today.month
[ bills, daily, savings ].each do |group|
  group.categories.each do |cat|
    BudgetEntry.find_or_create_by!(category: cat, year: current_year, month: current_month)
  end
end

puts "Seed 完成！登入帳號：jerry@example.com / password123"
