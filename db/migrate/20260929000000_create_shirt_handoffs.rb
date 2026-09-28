class CreateShirtHandoffs < ActiveRecord::Migration[8.1]
  def change
    create_table :shirt_handoffs do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :size
      t.integer :status, null: false, default: 0
      t.text :note
      t.datetime :given_at

      t.timestamps
    end

    # One row per existing user so the swag page never has gaps.
    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          INSERT INTO shirt_handoffs (user_id, created_at, updated_at)
          SELECT id, NOW(), NOW() FROM users
          ON CONFLICT (user_id) DO NOTHING
        SQL
      end
    end
  end
end
