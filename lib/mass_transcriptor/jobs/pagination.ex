defmodule MassTranscriptor.Jobs.Pagination do
  @moduledoc false

  @default_page_size 15

  def default_page_size, do: @default_page_size

  def paginate(collection, page, opts \\ []) when is_list(collection) do
    page_size = Keyword.get(opts, :page_size, @default_page_size)
    total_count = length(collection)
    total_pages = total_pages(total_count, page_size)
    page = normalize_page(page, total_pages)
    offset = (page - 1) * page_size
    rows = Enum.slice(collection, offset, page_size)

    %{
      rows: rows,
      page: page,
      page_size: page_size,
      total_count: total_count,
      total_pages: total_pages,
      from: if(total_count == 0, do: 0, else: offset + 1),
      to: offset + length(rows)
    }
  end

  def normalize_page(page, total_pages) when is_binary(page) do
    case Integer.parse(page) do
      {number, _} -> normalize_page(number, total_pages)
      :error -> 1
    end
  end

  def normalize_page(page, total_pages)
      when is_integer(page) and page >= 1 and page <= total_pages,
      do: page

  def normalize_page(page, total_pages) when is_integer(page) and page > total_pages,
    do: max(total_pages, 1)

  def normalize_page(_page, _total_pages), do: 1

  defp total_pages(0, _page_size), do: 1

  defp total_pages(count, page_size) do
    div(count + page_size - 1, page_size)
  end
end
