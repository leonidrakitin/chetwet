# frozen_string_literal: true

# Seed services and providers for testing

account = Account.first

return unless account

# Create service schedule if not exists
schedule = account.service_schedule || account.create_service_schedule!(
  timezone: 'Europe/Moscow',
  slot_interval_minutes: 30
)

# Create sample providers
providers = [
  { name: 'Иван Петров', description: 'Мастер по стрижке', active: true },
  { name: 'Мария Иванова', description: 'Парикмахер-стилист', active: true },
  { name: 'Алексей Сидоров', description: 'Барбер', active: true }
].map { |attrs| account.service_providers.create!(attrs) }

# Create sample services
services = [
  { name: 'Мужская стрижка', duration_minutes: 30, price: 1500, currency: 'RUB', active: true },
  { name: 'Женская стрижка', duration_minutes: 45, price: 2000, currency: 'RUB', active: true },
  { name: 'Окрашивание', duration_minutes: 90, price: 3500, currency: 'RUB', active: true },
  { name: 'Укладка', duration_minutes: 30, price: 1000, currency: 'RUB', active: true },
  { name: 'Борода', duration_minutes: 20, price: 800, currency: 'RUB', active: true }
].map { |attrs| account.services.create!(attrs) }

puts "Created #{providers.count} service providers"
puts "Created #{services.count} services"
puts 'Created service schedule'
