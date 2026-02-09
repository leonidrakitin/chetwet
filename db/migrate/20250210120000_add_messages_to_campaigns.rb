# frozen_string_literal: true

class AddMessagesToCampaigns < ActiveRecord::Migration[7.0]
  def change
    add_column :campaigns, :messages, :jsonb
  end
end
