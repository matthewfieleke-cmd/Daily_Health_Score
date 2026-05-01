type DiscouragementModalProps = {
  open: boolean;
  text: string | null;
  onClose: () => void;
};

export function DiscouragementModal({
  open,
  text,
  onClose,
}: DiscouragementModalProps) {
  if (!open || !text) return null;

  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div
        className="modal-panel"
        role="dialog"
        aria-modal="true"
        aria-labelledby="disc-title"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 id="disc-title" className="modal-title">
          A grounded reminder
        </h2>
        <p className="modal-body">{text}</p>
        <button type="button" className="btn-primary" onClick={onClose}>
          Close
        </button>
      </div>
    </div>
  );
}
