defmodule MassTranscriptor.Jobs.PaginationTest do
  use ExUnit.Case, async: true

  alias MassTranscriptor.Jobs.Pagination

  test "paginate/3 returns first page slice" do
    items = Enum.to_list(1..20)

    assert %{
             rows: rows,
             page: 1,
             page_size: 15,
             total_count: 20,
             total_pages: 2,
             from: 1,
             to: 15
           } = Pagination.paginate(items, 1)

    assert rows == Enum.to_list(1..15)
  end

  test "paginate/3 returns second page slice" do
    items = Enum.to_list(1..20)

    assert %{rows: rows, page: 2, from: 16, to: 20} = Pagination.paginate(items, 2)

    assert rows == Enum.to_list(16..20)
  end

  test "paginate/3 normalizes invalid and out-of-range pages" do
    items = Enum.to_list(1..10)

    assert %{page: 1} = Pagination.paginate(items, "0")
    assert %{page: 1} = Pagination.paginate(items, "abc")
    assert %{page: 2, rows: [6, 7, 8, 9, 10]} = Pagination.paginate(items, 99, page_size: 5)
  end

  test "paginate/3 handles empty collection" do
    assert %{
             rows: [],
             page: 1,
             total_count: 0,
             total_pages: 1,
             from: 0,
             to: 0
           } = Pagination.paginate([], 1)
  end
end
