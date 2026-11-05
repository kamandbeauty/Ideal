// Subtitle codecs. SRT is the exchange format, ASS is the only format that can
// carry SubFlow's styling, RTL settings and karaoke effects into other editors.
#pragma once

#include <string>
#include <vector>

#include "sf_common.h"

namespace sf {

// Subset of the ASS style that SubFlow can round-trip losslessly.
// Colours are stored as 0xRRGGBB; the writer converts to ASS's &HAABBGGRR&.
struct AssStyle {
  std::string name = "SubFlow";
  std::string font_name = "Vazirmatn";
  double font_size = 64.0;   // script pixels (PlayResY based)
  std::uint32_t primary_color = 0xFFFFFF;
  std::uint32_t outline_color = 0x000000;
  std::uint32_t back_color = 0x000000;
  bool bold = false;
  bool italic = false;
  bool underline = false;
  double outline_width = 3.0;
  double shadow_depth = 1.5;
  double spacing = 0.0;      // letter spacing, ASS \fspx
  double line_spacing = 1.0; // multiplier, applied via \fsp? -> see writer docs
  int alignment = 2;         // ASS numpad alignment (2 = bottom center)
  int margin_v = 60;
  int margin_l = 40;
  int margin_r = 40;
  bool rtl = false;          // logical-order text is always emitted; see note below
  int border_style = 1;      // 1 = outline+shadow, 3 = opaque box
  double scale_x = 100.0;
  double scale_y = 100.0;
  double angle = 0.0;
};

struct SubtitleWriteResult {
  std::string content;
  int written = 0;
  int skipped = 0;
};

// UTF-8 in, UTF-8 out. CRLF line endings, no BOM, trailing newline.
SubtitleWriteResult WriteSrt(const std::vector<Segment>& segments);

// `video_width` / `video_height` become PlayResX / PlayResY so that font sizes
// measured in the preview (which renders at video resolution) match the export
// exactly. RTL text is emitted in logical order: both libass and VSFilter run
// the Unicode BiDi algorithm themselves, so pre-shaping or pre-reversing would
// produce doubled reshaping and broken parentheses.
SubtitleWriteResult WriteAss(const std::vector<Segment>& segments, const AssStyle& style,
                             int video_width, int video_height);

struct SrtParseResult {
  std::vector<Segment> segments;
  std::vector<std::string> warnings;
};

// Tolerant: accepts BOM, CRLF/LF/CR, missing indices, ',' or '.' millisecond
// separators, extra spaces around the arrow, and overlapping cues.
SrtParseResult ParseSrt(const std::string& content);

// Escapes text for ASS: newline -> \N, and braces are replaced by their
// fullwidth forms because ASS has no brace escape sequence (a literal '{'
// would be parsed as an override block and corrupt the line).
std::string EscapeAssText(const std::string& text);

}  // namespace sf
