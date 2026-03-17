class CreateSuggestions < ActiveRecord::Migration[7.0]
  def change
    create_table :suggestions do |t|
      t.string :title, null: false
      t.text :description
      t.string :status, default: 'pending', null: false
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :upvotes_count, default: 0, null: false
      t.integer :downvotes_count, default: 0, null: false
      t.string :tags, array: true, default: []
      t.timestamps
    end

    add_index :suggestions, :status
    add_index :suggestions, :tags, using: :gin

    create_table :suggestion_votes do |t|
      t.references :suggestion, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :vote_type, null: false # 'upvote' or 'downvote'
      t.timestamps
    end

    add_index :suggestion_votes, [:suggestion_id, :user_id], unique: true
  end
end
