# ==============================================================
#  FaceInsight – backend/services/upload_service.py
#  Image upload + storage
# ==============================================================

import os
import uuid
import cloudinary
import cloudinary.uploader
from fastapi import UploadFile
from loguru import logger
from core.config import get_settings

settings = get_settings()

# Initialize Cloudinary configuration
cloudinary.config(
    cloud_name=settings.CLOUDINARY_CLOUD_NAME,
    api_key=settings.CLOUDINARY_API_KEY,
    api_secret=settings.CLOUDINARY_API_SECRET,
    secure=True
)

class UploadService:
    """Handle image upload + storage"""

    async def save_image(self, file: UploadFile, user_id: int) -> dict:
        """
        Upload image directly to Cloudinary.
        Returns: Dict containing secure_url and size_bytes
        """
        try:
            # Read file contents into memory
            contents = await file.read()
            
            # Upload to Cloudinary
            logger.info(f"Uploading image to Cloudinary for user {user_id}...")
            upload_result = cloudinary.uploader.upload(
                contents,
                folder=f"faceinsight/user_{user_id}",
                public_id=str(uuid.uuid4()),
                resource_type="image"
            )
            
            secure_url = upload_result.get("secure_url")
            size_bytes = upload_result.get("bytes", 0)
            
            logger.info(f"Image uploaded successfully: {secure_url}")
            
            return {
                "url": secure_url,
                "size_bytes": size_bytes,
                "filename": f"{upload_result.get('public_id')}.{upload_result.get('format', 'jpg')}"
            }
            
        except Exception as e:
            logger.error(f"Cloudinary upload failed: {e}")
            raise
