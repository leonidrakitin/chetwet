class AddRequiredSlotsToCaptainScenarios < ActiveRecord::Migration[7.1]
  def change
    add_column :captain_scenarios, :required_slots, :jsonb, default: []
  end
end
