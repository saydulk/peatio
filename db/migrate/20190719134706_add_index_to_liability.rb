class AddIndexToLiability < ActiveRecord::Migration[5.2]
  def change
    add_index(:liabilities, %i[code currency_id member_id], name: 'index_groupkey')
  end
end
