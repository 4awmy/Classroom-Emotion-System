import asyncio
import sounddevice as sd
import numpy as np
import io
import wave
from datetime import datetime
from openai import OpenAI
from database import SessionLocal
from models import Transcript
import os

# Initialize OpenAI
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# Shared connection manager (from session router)
# In a real app, this would be a proper service/class
from routers.session import manager

async def stream_captions(lecture_id: str, stop_event: asyncio.Event):
    """
    Async loop to capture audio chunks and broadcast captions.
    """
    print(f"[WHISPER] Starting audio stream for lecture {lecture_id}")
    
    samplerate = 16000
    duration = 5 # seconds
    
    while not stop_event.is_set():
        try:
            # 1. Capture 5s audio
            # Note: This is blocking, but in a real async app we'd use a non-blocking recording method
            # For MVP, we'll run it in a thread or use a loop
            loop = asyncio.get_event_loop()
            audio = await loop.run_in_executor(None, lambda: sd.rec(int(duration * samplerate), samplerate=samplerate, channels=1, dtype='int16'))
            await loop.run_in_executor(None, sd.wait)
            
            # 2. Convert to WAV in memory
            buffer = io.BytesIO()
            with wave.open(buffer, 'wb') as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2) # 16-bit
                wf.setframerate(samplerate)
                wf.writeframes(audio.tobytes())
            
            buffer.seek(0)
            buffer.name = "audio.wav"
            
            # 3. Transcribe via Whisper
            resp = client.audio.transcriptions.create(
                model="whisper-1",
                file=buffer
            )
            text = resp.text.strip()
            
            if text:
                # 4. Save to DB
                db = SessionLocal()
                new_transcript = Transcript(
                    lecture_id=lecture_id,
                    timestamp=datetime.utcnow(),
                    chunk_text=text,
                    language="mixed" # Whisper auto-detects
                )
                db.add(new_transcript)
                db.commit()
                db.close()
                
                # 5. Broadcast via WS
                payload = {
                    "type": "caption",
                    "text": text,
                    "lecture_id": lecture_id,
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                    "language": "mixed"
                }
                await manager.broadcast(payload)
                print(f"[WHISPER] Broadcast: {text[:50]}...")
            
        except Exception as e:
            print(f"[WHISPER] Error: {e}")
            await asyncio.sleep(1)
            
    print(f"[WHISPER] Audio stream stopped for lecture {lecture_id}")
