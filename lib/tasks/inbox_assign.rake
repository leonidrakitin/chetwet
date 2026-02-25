# frozen_string_literal: true

namespace :inbox do
  desc 'Assign all account users to an inbox (by id or name). Use: rails inbox:assign_all[6] or inbox:assign_all["WhatsApp Cloud"]'
  task :assign_all, [:inbox_id_or_name] => :environment do |_t, args|
    inbox_id_or_name = args[:inbox_id_or_name]
    raise 'Usage: rails inbox:assign_all[INBOX_ID] or inbox:assign_all["Inbox name"]' if inbox_id_or_name.blank?

    inbox = if inbox_id_or_name.to_s.match?(/\A\d+\z/)
              Inbox.find_by(id: inbox_id_or_name)
            else
              Inbox.find_by('name ILIKE ?', "%#{inbox_id_or_name}%")
            end

    raise "Inbox not found: #{inbox_id_or_name}" if inbox.nil?

    account = inbox.account
    users = account.users
    added = 0
    users.each do |user|
      next if inbox.members.include?(user)

      inbox.inbox_members.create!(user: user)
      added += 1
      puts "  Added user: #{user.email} (id=#{user.id})"
    end
    puts "Inbox '#{inbox.name}' (id=#{inbox.id}): #{added} user(s) assigned, #{inbox.members.count} total."
  end
end
