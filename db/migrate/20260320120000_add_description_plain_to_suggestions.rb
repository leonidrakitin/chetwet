# frozen_string_literal: true

class AddDescriptionPlainToSuggestions < ActiveRecord::Migration[7.1]
  def up
    add_column :suggestions, :description_plain, :text

    Suggestion.reset_column_information
    Suggestion.find_each do |s|
      plain = ActionController::Base.helpers.strip_tags(s.description.to_s).squish
      s.update_column(:description_plain, plain.presence)
    end
  end

  def down
    remove_column :suggestions, :description_plain
  end
end
