extends Node
## Consent is shown only after a configured service determines it is legally required.

signal consent_required
signal consent_changed

enum Status { NOT_REQUIRED, REQUIRED, GRANTED, DENIED }
var status := Status.NOT_REQUIRED


func configure(requires_consent: bool) -> void:
	status = Status.REQUIRED if requires_consent else Status.NOT_REQUIRED
	if status == Status.REQUIRED:
		consent_required.emit()


func set_consent(granted: bool) -> void:
	if status != Status.REQUIRED:
		return
	status = Status.GRANTED if granted else Status.DENIED
	consent_changed.emit(status)


func permits_optional_services() -> bool:
	return status in [Status.NOT_REQUIRED, Status.GRANTED]
