from fastapi import WebSocket
from typing import List, Optional
import asyncio

_main_loop: Optional[asyncio.AbstractEventLoop] = None

def set_main_loop(loop: asyncio.AbstractEventLoop):
    global _main_loop
    _main_loop = loop

def get_main_loop() -> Optional[asyncio.AbstractEventLoop]:
    return _main_loop


class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        dead = []
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except Exception:
                dead.append(connection)
        for connection in dead:
            self.disconnect(connection)

    def broadcast_sync(self, message: dict):
        """Thread-safe way to broadcast from synchronous code (like Vision Pipeline)."""
        loop = get_main_loop()
        if loop and loop.is_running():
            loop.call_soon_threadsafe(
                lambda: asyncio.create_task(self.broadcast(message))
            )
        else:
            # Fallback if loop isn't captured yet
            print(f"[WS] Warning: Cannot broadcast_sync, main loop not set or not running.")


manager = ConnectionManager()
