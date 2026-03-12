class AddInboxToYclientsIntegrations < ActiveRecord::Migration[7.0]
  def change
    add_reference :yclients_integrations, :inbox, foreign_key: true
  end
end
