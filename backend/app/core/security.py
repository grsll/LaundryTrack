from datetime import datetime, timedelta, timezone
import hashlib
import secrets
from typing import Any, Dict, Optional
from jose import JWTError, jwt
from pwdlib import PasswordHash
from pwdlib.hashers.argon2 import Argon2Hasher
from pwdlib.hashers.bcrypt import BcryptHasher
from app.core.config import settings

# Password hashing context with Argon2id primary and Bcrypt fallback
password_hasher = PasswordHash((Argon2Hasher(), BcryptHasher()))


def hash_password(password: str) -> str:
    """Hashes a plaintext password using Argon2id."""
    return password_hasher.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifies a plaintext password against an Argon2id/bcrypt hash."""
    return password_hasher.verify(plain_password, hashed_password)


def hash_token(token: str) -> str:
    """Produces a deterministic SHA-256 hash of an opaque token for DB storage."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def generate_random_token(nbytes: int = 48) -> str:
    """Generates a high-entropy cryptographically secure URL-safe token."""
    return secrets.token_urlsafe(nbytes)


def create_access_token(
    claims: Dict[str, Any],
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Encodes a JWT access token containing subject, tenant, outlet, and role claims."""
    to_encode = claims.copy()
    now = datetime.now(timezone.utc)
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode.update({
        "exp": expire,
        "iat": now,
        "type": "access",
    })
    return jwt.encode(
        to_encode,
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM,
    )


def decode_access_token(token: str) -> Dict[str, Any]:
    """Decodes and validates a JWT access token."""
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        if payload.get("type") != "access":
            raise JWTError("Invalid token type")
        return payload
    except JWTError as e:
        raise ValueError(f"Invalid or expired access token: {e}")
