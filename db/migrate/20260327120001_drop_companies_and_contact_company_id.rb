# frozen_string_literal: true

class DropCompaniesAndContactCompanyId < ActiveRecord::Migration[7.1]
  def up
    remove_reference :contacts, :company, index: true if column_exists?(:contacts, :company_id)
    drop_table :companies if table_exists?(:companies)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
