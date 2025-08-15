class CreateSupportedLanguages < ActiveRecord::Migration[7.1]
  def change
    create_table :supported_languages do |t|
      t.string :code, null: false, limit: 10
      t.string :name, null: false, limit: 100
      t.string :native_name, null: false, limit: 100
      t.boolean :enabled, default: true, null: false
      t.text :description

      t.timestamps
    end

    add_index :supported_languages, :code, unique: true
    add_index :supported_languages, :enabled
  end
end
