class AddAuthorAndBodyToNotes < ActiveRecord::Migration[7.1]
  def change
    add_column :notes, :author_id, :bigint, :null => true
    add_foreign_key :notes, :users, :column => :author_id, :validate => false

    add_column :notes, :author_ip, :inet, :null => true
    add_column :notes, :body, :text, :null => true
  end
end
