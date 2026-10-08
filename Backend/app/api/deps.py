from typing import Generator, Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.security import decode_access_token
from app.models.sql_models import Shipper

security_bearer = HTTPBearer(auto_error=False)

def get_db() -> Generator[Session, None, None]:
    """Yields a managed database session with automatic cleanup."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_current_shipper(
    auth: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    db: Session = Depends(get_db)
) -> Shipper:
    """
    Enforces JWT authentication on endpoints.
    Decodes the Bearer token and returns the authenticated Shipper record.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate authentication credentials. Please provide a valid Bearer token.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if not auth or not auth.credentials:
        raise credentials_exception

    payload = decode_access_token(auth.credentials)
    if payload is None:
        raise credentials_exception

    email: Optional[str] = payload.get("sub")
    if email is None:
        raise credentials_exception

    shipper = db.query(Shipper).filter(Shipper.email == email).first()
    if shipper is None:
        # Also check if sub is shipper_id integer
        try:
            shipper_id = int(email)
            shipper = db.query(Shipper).filter(Shipper.shipper_id == shipper_id).first()
        except ValueError:
            pass

    if shipper is None:
        raise credentials_exception

    return shipper

def get_optional_shipper(
    auth: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    db: Session = Depends(get_db)
) -> Optional[Shipper]:
    """Allows endpoints to read token if present, but doesn't block unauthenticated callers."""
    if not auth or not auth.credentials:
        return None
    payload = decode_access_token(auth.credentials)
    if not payload or not payload.get("sub"):
        return None
    email = payload.get("sub")
    return db.query(Shipper).filter(Shipper.email == email).first()
