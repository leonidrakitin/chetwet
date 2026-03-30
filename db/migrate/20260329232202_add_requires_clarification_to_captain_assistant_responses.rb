# frozen_string_literal: true

class AddRequiresClarificationToCaptainAssistantResponses < ActiveRecord::Migration[7.1]
  def change
    add_column :captain_assistant_responses, :requires_clarification, :boolean, null: false, default: false
  end
end
