class CreateOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :orders do |t|

      t.string :order_id, unique: true

      t.timestamps
    end
  end
end
