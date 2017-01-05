require "cases/helper"

class PostgresqlInfinityTest < ActiveRecord::PostgreSQLTestCase
  include InTimeZone

  class PostgresqlInfinity < ActiveRecord::Base
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:postgresql_infinities) do |t|
      t.float :float
      t.datetime :datetime
      t.date :date
    end
  end

  teardown do
    @connection.drop_table "postgresql_infinities", if_exists: true
  end

  test "type casting infinity on a float column" do
    record = PostgresqlInfinity.create!(float: Float::INFINITY)
    record.reload
    assert_equal Float::INFINITY, record.float
  end

  test "type casting string on a float column" do
    record = PostgresqlInfinity.new(float: "Infinity")
    assert_equal Float::INFINITY, record.float
    record = PostgresqlInfinity.new(float: "-Infinity")
    assert_equal(-Float::INFINITY, record.float)
    record = PostgresqlInfinity.new(float: "NaN")
    assert_send [record.float, :nan?]
  end

  test "update_all with infinity on a float column" do
    record = PostgresqlInfinity.create!
    PostgresqlInfinity.update_all(float: Float::INFINITY)
    record.reload
    assert_equal Float::INFINITY, record.float
  end

  test "type casting string on a datetime column" do
    record = PostgresqlInfinity.create!(datetime: 'infinity')
    record.reload
    assert_equal Float::INFINITY, record.datetime
  end

  test "type casting constant on a datetime column" do
    record = PostgresqlInfinity.create!(datetime: Float::INFINITY)
    record.reload
    assert_equal Float::INFINITY, record.datetime
  end

  test "type casting string on a date column" do
    record = PostgresqlInfinity.create!(date: 'infinity')
    record.reload
    assert_equal Float::INFINITY, record.date
  end

  test "type casting constant on a date column" do
    record = PostgresqlInfinity.create!(date: Float::INFINITY)
    record.reload
    assert_equal Float::INFINITY, record.date
  end

  test "update_all with infinity on a datetime column" do
    record = PostgresqlInfinity.create!
    PostgresqlInfinity.update_all(datetime: Float::INFINITY)
    record.reload
    assert_equal Float::INFINITY, record.datetime
  end

  test "assigning 'infinity' on a datetime column with TZ aware attributes" do
    begin
      in_time_zone "Pacific Time (US & Canada)" do
        record = PostgresqlInfinity.create!(datetime: "infinity")
        assert_equal Float::INFINITY, record.datetime
        assert_equal record.datetime, record.reload.datetime
      end
    ensure
      # setting time_zone_aware_attributes causes the types to change.
      # There is no way to do this automatically since it can be set on a superclass
      PostgresqlInfinity.reset_column_information
    end
  end

  test "where clause with infinite range (strings) on a datetime column" do
    record = PostgresqlInfinity.create!(datetime: Time.current)
    found = PostgresqlInfinity.where(datetime: '-infinity'..'infinity').first
    assert_equal record, found
  end

  test "where clause with infinite range (constants) on a datetime column" do
    record = PostgresqlInfinity.create!(datetime: Time.current)
    found = PostgresqlInfinity.where(datetime: -::Float::INFINITY..::Float::INFINITY).first
    assert_equal record, found
  end

  test "where clause with infinite range (strings) on a date column" do
    record = PostgresqlInfinity.create!(date: Date.current)
    found = PostgresqlInfinity.where(date: '-infinity'..'infinity').first
    assert_equal record, found
  end

  test "where clause with infinite range (constants) on a date column" do
    record = PostgresqlInfinity.create!(date: Date.current)
    found = PostgresqlInfinity.where(date: -::Float::INFINITY..::Float::INFINITY).first
    assert_equal record, found
  end
end
