#include "sf_subtitle.h"

#include "sf_time.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <utility>
#include <vector>

namespace sf {
namespace {

const char kUtf8Bom[] = "\xEF\xBB\xBF";

std::string FormatAssColor(std::uint32_t rgb, std::uint8_t alpha = 0x00) {
  char buf[16];
  const unsigned r = (rgb >> 16) & 0xFFu;
  const unsigned g = (rgb >> 8) & 0xFFu;
  const unsigned b = rgb & 0xFFu;
  std::snprintf(buf, sizeof(buf), "&H%02X%02X%02X%02X", alpha, b, g, r);
  return std::string(buf);
}

std::string TrimCopy(const std::string& s) {
  std::size_t begin = 0;
  std::size_t end = s.size();
  while (begin < end && (s[begin] == ' ' || s[begin] == '\t' || s[begin] == '\r')) ++begin;
  while (end > begin && (s[end - 1] == ' ' || s[end - 1] == '\t' || s[end - 1] == '\r')) --end;
  return s.substr(begin, end - begin);
}

bool IsDigit(char c) { return c >= '0' && c <= '9'; }

// Parses "hh:mm:ss,mmm" / "h:mm:ss.mmm" / "mm:ss,mmm" / "hh:mm:ss".
bool ParseSrtTime(const std::string& raw, Micros* out_us) {
  std::string s = TrimCopy(raw);
  if (s.empty() || out_us == nullptr) return false;

  // 1. Split off the fractional part (SRT uses ',', many tools emit '.').
  std::string whole = s;
  long fraction = 0;
  const std::size_t sep = s.find_first_of(",.");
  if (sep != std::string::npos) {
    whole = s.substr(0, sep);
    const std::string frac = s.substr(sep + 1);
    if (frac.empty()) return false;
    int digits = 0;
    for (char c : frac) {
      if (!IsDigit(c)) return false;
      if (digits < 3) fraction = fraction * 10 + (c - '0');
      ++digits;
    }
    while (digits < 3) {  // ".5" means 500 ms, not 5 ms
      fraction *= 10;
      ++digits;
    }
  }

  // 2. Split the integer part on ':' -> [ss] | [mm, ss] | [hh, mm, ss].
  std::vector<std::string> parts;
  std::string current;
  for (char c : whole) {
    if (c == ':') {
      parts.push_back(current);
      current.clear();
    } else if (IsDigit(c)) {
      current.push_back(c);
    } else if (c == ' ' || c == '\t') {
      continue;
    } else {
      return false;
    }
  }
  parts.push_back(current);
  if (parts.empty() || parts.size() > 3) return false;
  for (const std::string& p : parts) {
    if (p.empty()) return false;
  }

  long values[3] = {0, 0, 0};
  const std::size_t n = parts.size();
  for (std::size_t i = 0; i < n; ++i) {
    values[i] = std::strtol(parts[i].c_str(), nullptr, 10);
  }
  long h = 0;
  long m = 0;
  long sec = 0;
  if (n == 3) {
    h = values[0];
    m = values[1];
    sec = values[2];
  } else if (n == 2) {
    m = values[0];
    sec = values[1];
  } else {
    sec = values[0];
  }
  *out_us = ((h * 3600 + m * 60 + sec) * kUsPerSec) + fraction * 1000;
  return true;
}

void SplitLines(const std::string& content, std::vector<std::string>* lines) {
  std::string current;
  for (std::size_t i = 0; i < content.size(); ++i) {
    const char c = content[i];
    if (c == '\n') {
      lines->push_back(current);
      current.clear();
    } else if (c == '\r') {
      if (i + 1 < content.size() && content[i + 1] == '\n') continue;
      lines->push_back(current);
      current.clear();
    } else {
      current.push_back(c);
    }
  }
  lines->push_back(current);
}

}  // namespace

std::string EscapeAssText(const std::string& text) {
  std::string out;
  out.reserve(text.size() + 8);
  for (std::size_t i = 0; i < text.size(); ++i) {
    const char c = text[i];
    if (c == '\r') continue;
    if (c == '\n') {
      out += "\\N";
    } else if (c == '{') {
      out += "\xEF\xBD\x9B";  // U+FF5B FULLWIDTH LEFT CURLY BRACKET
    } else if (c == '}') {
      out += "\xEF\xBD\x9D";  // U+FF5D FULLWIDTH RIGHT CURLY BRACKET
    } else {
      out.push_back(c);
    }
  }
  return out;
}

SubtitleWriteResult WriteSrt(const std::vector<Segment>& segments) {
  SubtitleWriteResult result;
  int index = 1;
  for (const Segment& s : segments) {
    if (s.end_us <= s.start_us || s.text.empty()) {
      ++result.skipped;
      continue;
    }
    result.content += std::to_string(index++);
    result.content += "\r\n";
    result.content += FormatSrtTime(s.start_us);
    result.content += " --> ";
    result.content += FormatSrtTime(s.end_us);
    result.content += "\r\n";
    // Normalise internal line endings to CRLF and drop a trailing newline.
    std::vector<std::string> lines;
    SplitLines(s.text, &lines);
    while (lines.size() > 1 && lines.back().empty()) lines.pop_back();
    for (std::size_t i = 0; i < lines.size(); ++i) {
      if (i > 0) result.content += "\r\n";
      result.content += lines[i];
    }
    result.content += "\r\n\r\n";
    ++result.written;
  }
  return result;
}

SubtitleWriteResult WriteAss(const std::vector<Segment>& segments, const AssStyle& style,
                             int video_width, int video_height) {
  SubtitleWriteResult result;
  const int w = video_width > 0 ? video_width : 1080;
  const int h = video_height > 0 ? video_height : 1920;

  result.content += "[Script Info]\r\n";
  result.content += "; Written by SubFlow - deterministic style mapping\r\n";
  result.content += "ScriptType: v4.00+\r\n";
  result.content += "WrapStyle: 2\r\n";
  result.content += "ScaledBorderAndShadow: yes\r\n";
  result.content += "YCbCr Matrix: TV.709\r\n";
  result.content += "PlayResX: " + std::to_string(w) + "\r\n";
  result.content += "PlayResY: " + std::to_string(h) + "\r\n";
  // Encoding 1 (default) keeps UTF-8 text untouched; RTL shaping is done by the
  // BiDi algorithm of the renderer, exactly like the in-app preview.
  result.content += "Encoding: 1\r\n";
  result.content += "\r\n[V4+ Styles]\r\n";
  result.content +=
      "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, "
      "BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, "
      "BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\r\n";

  char line[1024];
  std::snprintf(line, sizeof(line),
                "Style: %s,%s,%.1f,%s,%s,%s,%s,%d,%d,%d,0,%.1f,%.1f,%.1f,%.1f,%d,%.1f,%.1f,%d,%d,%d,%d,1\r\n",
                style.name.c_str(), style.font_name.c_str(), style.font_size,
                FormatAssColor(style.primary_color).c_str(),
                FormatAssColor(style.primary_color).c_str(),
                FormatAssColor(style.outline_color).c_str(),
                FormatAssColor(style.back_color).c_str(), style.bold ? -1 : 0,
                style.italic ? -1 : 0, style.underline ? -1 : 0, style.scale_x, style.scale_y,
                style.spacing, style.angle, style.border_style, style.outline_width,
                style.shadow_depth, style.alignment, style.margin_l, style.margin_r,
                style.margin_v);
  result.content += line;
  result.content += "\r\n[Events]\r\n";
  result.content += "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, "
                    "Effect, Text\r\n";

  for (const Segment& s : segments) {
    if (s.end_us <= s.start_us || s.text.empty()) {
      ++result.skipped;
      continue;
    }
    const std::string style_name = s.style.empty() ? style.name : s.style;
    result.content += "Dialogue: 0,";
    result.content += FormatAssTime(s.start_us);
    result.content += ",";
    result.content += FormatAssTime(s.end_us);
    result.content += "," + style_name + ",,0,0,0,,";
    result.content += EscapeAssText(s.text);
    result.content += "\r\n";
    ++result.written;
  }
  return result;
}

SrtParseResult ParseSrt(const std::string& content) {
  SrtParseResult result;
  std::string body = content;
  if (body.compare(0, 3, kUtf8Bom) == 0) body.erase(0, 3);

  std::vector<std::string> lines;
  SplitLines(body, &lines);

  std::vector<std::string> block;
  auto flush = [&]() {
    if (block.empty()) return;
    std::size_t idx = 0;
    // Optional numeric index line.
    if (!block[idx].empty() && TrimCopy(block[idx]).find("-->") == std::string::npos) {
      bool numeric = true;
      const std::string first = TrimCopy(block[idx]);
      for (char c : first) {
        if (!IsDigit(c) && c != ' ') {
          numeric = false;
          break;
        }
      }
      if (numeric) ++idx;
    }
    if (idx >= block.size()) {
      result.warnings.push_back("block without timing");
      block.clear();
      return;
    }
    const std::string timing = block[idx];
    const std::size_t arrow = timing.find("-->");
    if (arrow == std::string::npos) {
      result.warnings.push_back("block without --> : " + TrimCopy(timing));
      block.clear();
      return;
    }
    Micros start_us = 0;
    Micros end_us = 0;
    if (!ParseSrtTime(timing.substr(0, arrow), &start_us) ||
        !ParseSrtTime(timing.substr(arrow + 3), &end_us)) {
      result.warnings.push_back("unparseable timing: " + TrimCopy(timing));
      block.clear();
      return;
    }
    std::string text;
    for (std::size_t i = idx + 1; i < block.size(); ++i) {
      if (!text.empty()) text += "\n";
      text += block[i];
    }
    if (end_us <= start_us) {
      result.warnings.push_back("non-positive duration at " + FormatSrtTime(start_us));
    } else if (!text.empty()) {
      Segment s;
      s.start_us = start_us;
      s.end_us = end_us;
      s.text = text;
      result.segments.push_back(std::move(s));
    }
    block.clear();
  };

  for (const std::string& raw : lines) {
    if (TrimCopy(raw).empty()) {
      flush();
    } else {
      block.push_back(raw);
    }
  }
  flush();

  // Sorting keeps the editor model invariant: cues are ordered by start time.
  for (std::size_t i = 1; i < result.segments.size(); ++i) {
    for (std::size_t j = i; j > 0 && result.segments[j - 1].start_us > result.segments[j].start_us;
         --j) {
      std::swap(result.segments[j - 1], result.segments[j]);
    }
  }
  return result;
}

}  // namespace sf
