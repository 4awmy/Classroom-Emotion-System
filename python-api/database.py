import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import sessionmaker, DeclarativeBase

# Load environment variables
load_dotenv()

# Data directory setup
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
if not os.path.exists(DATA_DIR):
    os.makedirs(DATA_DIR)

DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{os.path.join(DATA_DIR, 'classroom_emotions.db')}")

# Add check for Windows-style absolute paths in SQLite URLs
if DATABASE_URL.startswith("sqlite:///"):
    # Ensure it's using forward slashes and absolute path
    path = DATABASE_URL.split("///")[1]
    abs_path = os.path.abspath(path).replace("\\", "/")
    DATABASE_URL = f"sqlite:///{abs_path}"

if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)


# Only apply check_same_thread if using SQLite
connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(
    DATABASE_URL, connect_args=connect_args
)

# Enable WAL mode for concurrent reads during vision pipeline writes
# This fires once per raw DBAPI connection, not per SQLAlchemy session
@event.listens_for(engine, "connect")
def _set_sqlite_wal(dbapi_conn, connection_record):
    if DATABASE_URL.startswith("sqlite"):
        cursor = dbapi_conn.cursor()
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.close()

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
