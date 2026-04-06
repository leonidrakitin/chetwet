class AddCaptainModelsToPlans < ActiveRecord::Migration[7.1]
  def change
    add_column :plans, :captain_models, :jsonb, default: {}
  end
end
