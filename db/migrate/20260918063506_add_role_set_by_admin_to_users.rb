class AddRoleSetByAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role_set_by_admin, :boolean, default: false, null: false
  end
end
