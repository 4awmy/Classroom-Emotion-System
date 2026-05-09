# Shared state for video streaming
from typing import Dict

# Global dictionary to store the latest JPEG bytes per lecture_id
latest_frames: Dict[str, bytes] = {}
