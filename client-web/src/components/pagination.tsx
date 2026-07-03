type Props = {
  offset: number;
  limit: number;
  total: number;
  onOffsetChange: (offset: number) => void;
};

export function Pagination(props: Props) {
  const hasPrev = () => props.offset > 0;
  const hasMore = () => props.offset + props.limit < props.total;
  return (
    <div class="pagination">
      <button
        onClick={() => props.onOffsetChange(Math.max(0, props.offset - props.limit))}
        disabled={!hasPrev()}
      >
        Prev
      </button>
      <span>
        {props.offset + 1}–{Math.min(props.offset + props.limit, props.total)} of {props.total}
      </span>
      <button
        onClick={() => props.onOffsetChange(props.offset + props.limit)}
        disabled={!hasMore()}
      >
        Next
      </button>
    </div>
  );
}
