type DiscouragementModalProps = {
  open: boolean;
  text: string | null;
  title?: string;
  titleId?: string;
  onClose: () => void;
};

export function DiscouragementModal({
  open,
  text,
  title = "A grounded reminder",
  titleId = "disc-title",
  onClose,
}: DiscouragementModalProps) {
  if (!open || !text) return null;

  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div
        className="modal-panel"
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        onClick={(e) => e.stopPropagation()}
      >
        <h2 id={titleId} className="modal-title">
          {title}
        </h2>
        <p className="modal-body">{text}</p>
        <button type="button" className="btn-primary" onClick={onClose}>
          Close
        </button>
      </div>
    </div>
  );
}
