from sqlalchemy.orm import Session
from database import SessionLocal, engine
import models
from routers.auth import get_password_hash
import uuid

def seed_db():
    db = SessionLocal()
    # Create tables
    models.Base.metadata.create_all(bind=engine)
    
    # Check if admin already exists
    admin = db.query(models.Admin).filter(models.Admin.admin_id == "admin").first()
    if not admin:
        print("Seeding admin user...")
        new_admin = models.Admin(
            admin_id="admin",
            name="System Admin",
            email="admin@aast.edu",
            password_hash=get_password_hash("admin"),
            phone="0123456789"
        )
        db.add(new_admin)
        db.commit()
        print("Admin user created: admin/admin")
    else:
        print("Admin user already exists.")
        
    db.close()

if __name__ == "__main__":
    seed_db()
