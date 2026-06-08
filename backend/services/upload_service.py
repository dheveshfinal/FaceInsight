# ==============================================================
#  FaceInsight – backend/services/upload_service.py
#  Image upload + storage
# ==============================================================

import os
import aiofiles
from fastapi import UploadFile
from pathlib import Path
from loguru import logger
from core.config import get_settings

settings = get_settings()


class UploadService:
    """Handle image upload + storage"""

    async def save_image(self, file: UploadFile, user_id: int) -> str:
        """
        Save uploaded image to disk.
        Returns: stored_filename (relative path)
        """
        # Create user-specific directory
        user_dir = Path(settings.UPLOAD_DIR) / f"user_{user_id}"
        user_dir.mkdir(parents=True, exist_ok=True)

        # Generate filename
        import uuid

        ext = Path(file.filename or "image").suffix or ".jpg"
        filename = f"{uuid.uuid4()}{ext}"
        filepath = user_dir / filename

        # Save file
        try:
            contents = await file.read()
            async with aiofiles.open(filepath, "wb") as f:
                await f.write(contents)
            logger.info(f"Image saved: {filepath}")
            return str(filepath.relative_to(settings.UPLOAD_DIR))
        except Exception as e:
            logger.error(f"Upload failed: {e}")
            raise
