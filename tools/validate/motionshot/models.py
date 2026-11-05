"""Project model + JSON (de)serialisation — mirrors the Dart/Kotlin models."""

from __future__ import annotations

import json
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import List, Optional

from .audio import AudioSettings
from .profile import MotionProfile
from .timeline import TransitionSpec


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


@dataclass
class PhotoItem:
    id: str
    source_uri: str
    width: int
    height: int
    duration: float = 5.0
    order: int = 0
    motion: MotionProfile = field(default_factory=MotionProfile)
    transition: TransitionSpec = field(default_factory=TransitionSpec)
    display_name: str = ""

    @property
    def aspect(self) -> float:
        return self.width / self.height if self.height else 1.0

    def to_json(self) -> dict:
        return {
            "id": self.id, "sourceUri": self.source_uri,
            "width": self.width, "height": self.height,
            "duration": self.duration, "order": self.order,
            "motionProfile": self.motion.to_json(),
            "transitionProfile": self.transition.to_json(),
            "displayName": self.display_name,
        }

    @staticmethod
    def from_json(d: dict) -> "PhotoItem":
        return PhotoItem(
            id=d["id"], source_uri=d["sourceUri"],
            width=int(d["width"]), height=int(d["height"]),
            duration=float(d.get("duration", 5.0)),
            order=int(d.get("order", 0)),
            motion=MotionProfile.from_json(d.get("motionProfile", {})),
            transition=TransitionSpec.from_json(d.get("transitionProfile", {})),
            display_name=d.get("displayName", ""),
        )


@dataclass
class ExportSettings:
    width: int = 1920
    height: int = 1080
    fps: int = 30
    codec: str = "h264"          # h264 | hevc
    quality: str = "high"        # standard | high | maximum | custom
    bitrate: int = 0             # 0 -> derive from quality (§8.2)
    aspect: str = "16:9"         # 9:16 | 16:9 | 1:1 | 4:5 | original
    resolution_label: str = "1080p"

    def to_json(self) -> dict:
        return {
            "width": self.width, "height": self.height, "fps": self.fps,
            "codec": self.codec, "quality": self.quality,
            "bitrate": self.bitrate, "aspect": self.aspect,
            "resolutionLabel": self.resolution_label,
        }

    @staticmethod
    def from_json(d: dict) -> "ExportSettings":
        return ExportSettings(
            width=int(d.get("width", 1920)), height=int(d.get("height", 1080)),
            fps=int(d.get("fps", 30)), codec=d.get("codec", "h264"),
            quality=d.get("quality", "high"), bitrate=int(d.get("bitrate", 0)),
            aspect=d.get("aspect", "16:9"),
            resolution_label=d.get("resolutionLabel", "1080p"),
        )


@dataclass
class Project:
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    name: str = "Untitled"
    photos: List[PhotoItem] = field(default_factory=list)
    audio: Optional[AudioSettings] = field(default_factory=AudioSettings)
    aspect: str = "16:9"
    export_settings: ExportSettings = field(default_factory=ExportSettings)
    seed: int = 1
    created_at: str = field(default_factory=now_iso)
    updated_at: str = field(default_factory=now_iso)
    schema: int = 1

    # ---- derived
    @property
    def total_duration(self) -> float:
        return float(sum(p.duration for p in self.photos))

    def aspect_ratio(self) -> float:
        if self.aspect == "original" and self.photos:
            a = self.photos[0].aspect
            return max(9 / 16, min(16 / 9, a))
        return {
            "9:16": 9 / 16, "16:9": 16 / 9, "1:1": 1.0, "4:5": 4 / 5,
        }.get(self.aspect, 16 / 9)

    def sorted_photos(self) -> List[PhotoItem]:
        return sorted(self.photos, key=lambda p: p.order)

    # ---- io
    def to_json(self) -> dict:
        return {
            "schema": self.schema, "id": self.id, "name": self.name,
            "photos": [p.to_json() for p in self.photos],
            "audio": self.audio.to_json() if self.audio else None,
            "aspectRatio": self.aspect,
            "exportSettings": self.export_settings.to_json(),
            "seed": self.seed,
            "createdAt": self.created_at, "updatedAt": self.updated_at,
        }

    @staticmethod
    def from_json(d: dict) -> "Project":
        audio = None
        if d.get("audio"):
            a = d["audio"]
            audio = AudioSettings(
                path=a.get("path"), volume=float(a.get("volume", 1.0)),
                fade_in=float(a.get("fadeIn", 0.5)),
                fade_out=float(a.get("fadeOut", 1.0)),
                trim_start=float(a.get("trimStart", 0.0)),
                trim_end=a.get("trimEnd"), loop=bool(a.get("loop", True)),
            )
        return Project(
            id=d.get("id", str(uuid.uuid4())), name=d.get("name", "Untitled"),
            photos=[PhotoItem.from_json(p) for p in d.get("photos", [])],
            audio=audio, aspect=d.get("aspectRatio", "16:9"),
            export_settings=ExportSettings.from_json(d.get("exportSettings", {})),
            seed=int(d.get("seed", 1)),
            created_at=d.get("createdAt", now_iso()),
            updated_at=d.get("updatedAt", now_iso()),
            schema=int(d.get("schema", 1)),
        )

    def save(self, path: str) -> None:
        self.updated_at = now_iso()
        with open(path, "w", encoding="utf-8") as f:
            json.dump(self.to_json(), f, ensure_ascii=False, indent=2)

    @staticmethod
    def load(path: str) -> "Project":
        with open(path, encoding="utf-8") as f:
            return Project.from_json(json.load(f))
