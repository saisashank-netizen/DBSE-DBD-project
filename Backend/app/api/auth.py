from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, func
from app.api.deps import get_db, get_current_shipper
from app.models.sql_models import Shipper
from app.models.pydantic_schemas import (
    ShipperRegisterRequest, LoginRequest, TokenResponse, ShipperProfileResponse
)
from app.security import hash_password, verify_password, create_access_token
from app.config import settings

router = APIRouter(prefix="/auth", tags=["Authentication & Tokens"])

@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register_shipper(req: ShipperRegisterRequest, db: Session = Depends(get_db)):
    """
    Registers a new shipper account in MySQL, hashes the password using bcrypt,
    and returns a signed JWT access token.
    """
    existing = db.query(Shipper).filter(Shipper.email == req.email.lower()).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email address already exists."
        )

    hashed_pw = hash_password(req.password)
    new_shipper = Shipper(
        full_name=req.full_name,
        email=req.email.lower(),
        password_hash=hashed_pw,
        phone=req.phone,
        company_name=req.company_name
    )
    db.add(new_shipper)
    db.commit()
    db.refresh(new_shipper)

    # Issue JWT token
    token = create_access_token({"sub": new_shipper.email, "shipper_id": new_shipper.shipper_id})

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        expires_in_minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES,
        shipper=ShipperProfileResponse.model_validate(new_shipper)
    )

@router.post("/login", response_model=TokenResponse)
def login_shipper(req: LoginRequest, db: Session = Depends(get_db)):
    """
    Authenticates strictly against the users stored in the database.
    Checks if username/full_name or email exists in the MySQL database.
    Only if user exists AND password matches does it issue a JWT token.
    """
    identifier = (req.username_or_email or req.email or req.username or "").strip()
    if not identifier:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username or email is required."
        )

    # Query MySQL database for user by email, full name, or email prefix
    shipper = db.query(Shipper).filter(
        or_(
            func.lower(Shipper.email) == identifier.lower(),
            func.lower(Shipper.full_name) == identifier.lower(),
            Shipper.email.like(f"{identifier.lower()}@%")
        )
    ).first()

    if not shipper:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"User '{identifier}' does not exist in the database. Please check credentials or register."
        )

    # Strictly verify the password against the database record
    if not verify_password(req.password, shipper.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect password for this user. Access denied."
        )

    # Generate JWT access token with user details
    token = create_access_token({"sub": shipper.email, "shipper_id": shipper.shipper_id})

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        expires_in_minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES,
        shipper=ShipperProfileResponse.model_validate(shipper)
    )

@router.get("/me", response_model=ShipperProfileResponse)
def get_current_user_profile(current_shipper: Shipper = Depends(get_current_shipper)):
    """
    Protected endpoint: Fetches current authenticated shipper profile using JWT Bearer token.
    """
    return ShipperProfileResponse.model_validate(current_shipper)
