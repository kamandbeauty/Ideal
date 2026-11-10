import 'package:flutter/foundation.dart';

import '../../models/subtitle.dart';
import 'subtitle_document.dart';

/// Read-only view of the editor for the UI layer.
@immutable
class SubtitleEditorSnapshot {
  const SubtitleEditorSnapshot({
    required this.document,
    required this.selectionId,
    required this.clipboardStyleId,
    required this.dirty,
    required this.undoDepth,
    required this.redoDepth,
  });

  final SubtitleDocument document;
  final String? selectionId;
  final String? clipboardStyleId;

  /// True when the document differs from what the database holds.
  final bool dirty;
  final int undoDepth;
  final int redoDepth;

  bool get canUndo => undoDepth > 0;
  bool get canRedo => redoDepth > 0;
}

/// Editor state + undo history.
///
/// Free of Riverpod and of the database so the history rules are testable: every
/// mutation pushes the previous document, undo/redo swap between two stacks, and
/// the history is bounded. Documents are immutable, which is what makes undo a
/// real guarantee rather than a best effort.
class SubtitleEditorModel {
  SubtitleEditorModel({
    required SubtitleDocument document,
    this.historyLimit = 120,
    String? selectionId,
  })  : _document = document,
        _selectionId = selectionId ?? (document.isEmpty ? null : document.segments.first.id);

  final int historyLimit;
  final List<SubtitleDocument> _undo = <SubtitleDocument>[];
  final List<SubtitleDocument> _redo = <SubtitleDocument>[];
  SubtitleDocument _document;
  String? _selectionId;
  String? _clipboardStyleId;
  bool _dirty = false;

  SubtitleDocument get document => _document;
  String? get selectionId => _selectionId;
  String? get clipboardStyleId => _clipboardStyleId;
  String? get selectedStyleId {
    final String? id = _selectionId;
    return id == null ? null : _document.byId(id)?.styleId;
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  SubtitleEditorSnapshot get snapshot => SubtitleEditorSnapshot(
        document: _document,
        selectionId: _selectionId,
        clipboardStyleId: _clipboardStyleId,
        dirty: _dirty,
        undoDepth: _undo.length,
        redoDepth: _redo.length,
      );

  void select(String? segmentId) {
    _selectionId =
        segmentId != null && _document.byId(segmentId) != null ? segmentId : null;
  }

  // ------------------------------------------------------------- commands
  bool setText(String segmentId, String text) =>
      _commit(_document.withText(segmentId, text), select: segmentId);

  bool retime(String segmentId, {int? startUs, int? endUs}) =>
      _commit(_document.withTiming(segmentId, startUs: startUs, endUs: endUs), select: segmentId);

  bool insertAt(int atUs, {String text = ''}) {
    final Set<String> before =
        _document.segments.map((SubtitleSegment s) => s.id).toSet();
    final SubtitleDocument next = _document.insertAt(atUs, text: text);
    String? created;
    for (final SubtitleSegment segment in next.segments) {
      if (!before.contains(segment.id)) {
        created = segment.id;
        break;
      }
    }
    return _commit(next, select: created);
  }

  bool split(String segmentId, int atUs) =>
      _commit(_document.splitAt(segmentId, atUs), select: segmentId);

  bool mergeWithNext(String segmentId) =>
      _commit(_document.mergeWithNext(segmentId), select: segmentId);

  bool remove(String segmentId) {
    final int index = _document.indexOf(segmentId);
    final SubtitleDocument next = _document.remove(segmentId);
    if (next.length == _document.length) return false;
    final int fallbackIndex = index >= next.length ? next.length - 1 : index;
    final String? fallback = next.isEmpty ? null : next.segments[fallbackIndex].id;
    return _commit(next, select: fallback);
  }

  bool shiftAll(int deltaUs) => _commit(_document.shiftAll(deltaUs), select: _selectionId);

  /// Applies [styleId] to the selection, or to every caption when asked.
  bool assignStyle(String styleId, {bool applyToAll = false}) {
    final String? id = _selectionId;
    if (id == null) return false;
    final SubtitleDocument next = applyToAll
        ? _document.copyStyleFrom(id, _allIds())
        : _document.withStyle(id, styleId);
    return _commit(next, select: id);
  }

  /// Applies [styleId] to every caption in one undoable step.
  bool applyStyleToAll(String styleId) =>
      _commit(_document.withStyleAll(styleId), select: _selectionId);

  /// Appends a matching emoji to every caption that has none yet, in one
  /// undoable step. Returns how many captions changed.
  int addEmojis(String Function(String text) decorate) {
    SubtitleDocument next = _document;
    int changed = 0;
    for (final SubtitleSegment segment in _document.segments) {
      final String decorated = decorate(segment.text);
      if (decorated == segment.text) continue;
      next = next.withText(segment.id, decorated);
      changed++;
    }
    if (changed == 0) return 0;
    _commit(next, select: _selectionId);
    return changed;
  }

  /// Pins a per-caption style to [segmentId] (null clears it).
  bool setSegmentPreset(String segmentId, String? presetJson) =>
      _commit(_document.withPreset(segmentId, presetJson), select: segmentId);

  /// Applies [segmentId]'s own style to every caption in one undoable step.
  bool applySegmentPresetToAll(String segmentId) {
    if (_document.byId(segmentId) == null) return false;
    return _commit(_document.withPresetFrom(segmentId), select: segmentId);
  }

  /// Remembers the selected caption's style for "paste style".
  void copyStyle() {
    _clipboardStyleId = selectedStyleId;
  }

  bool pasteStyle({bool applyToAll = false}) {
    final String? clip = _clipboardStyleId;
    final String? id = _selectionId;
    if (clip == null || id == null) return false;
    final SubtitleDocument next = applyToAll
        ? _document.copyStyleFrom(id, _allIds())
        : _document.withStyle(id, clip);
    return _commit(next, select: id);
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    _redo.add(_document);
    _document = _undo.removeLast();
    _dirty = true;
    _fixSelection();
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    _undo.add(_document);
    _document = _redo.removeLast();
    _dirty = true;
    _fixSelection();
    return true;
  }

  /// Called after the document reached the database.
  void markSaved() {
    _dirty = false;
  }

  // -------------------------------------------------------------- internals
  Iterable<String> _allIds() => _document.segments.map((SubtitleSegment s) => s.id);

  bool _commit(SubtitleDocument next, {String? select}) {
    if (identical(next, _document)) return false;
    if (next.length == _document.length && _sameSegments(next, _document)) return false;
    _undo.add(_document);
    if (_undo.length > historyLimit) _undo.removeAt(0);
    _redo.clear();
    _document = next;
    _dirty = true;
    if (select != null && _document.byId(select) != null) _selectionId = select;
    _fixSelection();
    return true;
  }

  void _fixSelection() {
    final String? id = _selectionId;
    if (id != null && _document.byId(id) == null) {
      _selectionId = _document.isEmpty ? null : _document.segments.first.id;
    }
  }

  static bool _sameSegments(SubtitleDocument a, SubtitleDocument b) {
    for (int i = 0; i < a.segments.length; i++) {
      final SubtitleSegment x = a.segments[i];
      final SubtitleSegment y = b.segments[i];
      if (x.id != y.id ||
          x.text != y.text ||
          x.startUs != y.startUs ||
          x.endUs != y.endUs ||
          x.styleId != y.styleId ||
          // A per-caption style change is a real edit; without this the commit
          // is classified as a no-op and the style never reaches the document.
          x.presetJson != y.presetJson) {
        return false;
      }
    }
    return true;
  }
}
