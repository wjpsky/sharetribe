class AddUsernameToMarketplace < ActiveRecord::Migration
  def change
    add_column :communities, :username, :string, after: :id
  end
end
