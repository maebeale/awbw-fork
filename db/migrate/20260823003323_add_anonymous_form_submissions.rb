class AddAnonymousFormSubmissions < ActiveRecord::Migration[8.0]
  def up
    add_column :forms, :allow_anonymous_submissions, :boolean, default: false, null: false unless column_exists?(:forms, :allow_anonymous_submissions)
    change_column_null :form_submissions, :person_id, true
  end

  def down
    # Can't restore NOT NULL if anonymous (person-less) submissions exist; the
    # feature that created them is being removed, so drop those rows first.
    execute "DELETE FROM form_submissions WHERE person_id IS NULL"
    change_column_null :form_submissions, :person_id, false
    remove_column :forms, :allow_anonymous_submissions, if_exists: true
  end
end
