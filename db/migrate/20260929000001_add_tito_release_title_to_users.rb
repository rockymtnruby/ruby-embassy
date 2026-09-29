class AddTitoReleaseTitleToUsers < ActiveRecord::Migration[8.1]
  def change
    # Raw Tito release (ticket type) provenance per user. Nullable with no
    # default: existing rows read NULL until the next Tito sync backfills
    # them, so this is safe on a populated table.
    add_column :users, :tito_release_title, :string
  end
end
