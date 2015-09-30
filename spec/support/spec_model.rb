def SpecModel(table_name, setup, &block)
  ::ActiveRecord::Base.connection.create_table(table_name) do |t|
    setup.each do |column_name, type|
      t.column column_name, type
    end

    t.timestamps null: true
  end

  Class.new(::ActiveRecord::Base, &block).tap do |klass|
    klass.instance_variable_set '@table_name', table_name
  end
end
