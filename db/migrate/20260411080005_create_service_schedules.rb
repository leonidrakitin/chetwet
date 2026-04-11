class CreateServiceSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :service_schedules do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :timezone, default: 'UTC', null: false
      t.jsonb :working_hours, default: default_working_hours
      t.jsonb :holidays, default: []
      t.jsonb :breaks, default: []
      t.integer :slot_interval_minutes, default: 30, null: false

      t.timestamps
    end
  end

  private

  def default_working_hours
    {
      'monday' => { 'enabled' => true, 'slots' => [{ 'start' => '09:00', 'end' => '18:00' }] },
      'tuesday' => { 'enabled' => true, 'slots' => [{ 'start' => '09:00', 'end' => '18:00' }] },
      'wednesday' => { 'enabled' => true, 'slots' => [{ 'start' => '09:00', 'end' => '18:00' }] },
      'thursday' => { 'enabled' => true, 'slots' => [{ 'start' => '09:00', 'end' => '18:00' }] },
      'friday' => { 'enabled' => true, 'slots' => [{ 'start' => '09:00', 'end' => '18:00' }] },
      'saturday' => { 'enabled' => false, 'slots' => [] },
      'sunday' => { 'enabled' => false, 'slots' => [] }
    }.to_json
  end
end
