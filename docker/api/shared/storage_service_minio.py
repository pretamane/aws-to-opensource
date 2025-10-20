# MinIO Storage Service - Replaces AWS S3/EFS
import os
import logging
from typing import Optional, BinaryIO, Dict, Any, List
import boto3
from botocore.client import Config
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)

class MinIOStorageService:
    """MinIO storage service with S3-compatible API"""
    
    def __init__(self):
        self.endpoint_url = os.environ.get('S3_ENDPOINT_URL', 'http://minio:9000')
        self.access_key = os.environ.get('S3_ACCESS_KEY')
        self.secret_key = os.environ.get('S3_SECRET_KEY')
        
        if not self.access_key or not self.secret_key:
            raise ValueError("S3_ACCESS_KEY and S3_SECRET_KEY must be set")
        
        # Initialize S3-compatible client for MinIO
        self.client = boto3.client(
            's3',
            endpoint_url=self.endpoint_url,
            aws_access_key_id=self.access_key,
            aws_secret_access_key=self.secret_key,
            config=Config(signature_version='s3v4'),
            region_name='us-east-1'  # MinIO doesn't use regions, but boto3 requires it
        )
        
        self.data_bucket = os.environ.get('S3_DATA_BUCKET', 'pretamane-data')
        self.backup_bucket = os.environ.get('S3_BACKUP_BUCKET', 'pretamane-backup')
        
        logger.info(f"MinIO client initialized: {self.endpoint_url}")
        
        # Ensure buckets exist
        self._ensure_buckets()
    
    def _ensure_buckets(self):
        """Ensure required buckets exist"""
        buckets = [self.data_bucket, self.backup_bucket]
        
        try:
            existing_buckets = [b['Name'] for b in self.client.list_buckets()['Buckets']]
            
            for bucket in buckets:
                if bucket not in existing_buckets:
                    self.client.create_bucket(Bucket=bucket)
                    logger.info(f"Created bucket: {bucket}")
                else:
                    logger.info(f"Bucket exists: {bucket}")
                    
        except Exception as e:
            logger.warning(f"Error ensuring buckets: {str(e)}")
    
    def upload_file(self, file_content: bytes, key: str, bucket: Optional[str] = None, 
                   content_type: Optional[str] = None, metadata: Optional[Dict] = None) -> bool:
        """Upload file to MinIO (S3-compatible)"""
        try:
            bucket = bucket or self.data_bucket
            
            kwargs = {
                'Bucket': bucket,
                'Key': key,
                'Body': file_content
            }
            
            if content_type:
                kwargs['ContentType'] = content_type
            
            if metadata:
                kwargs['Metadata'] = metadata
            
            self.client.put_object(**kwargs)
            logger.info(f"Uploaded file to MinIO: s3://{bucket}/{key}")
            return True
            
        except Exception as e:
            logger.error(f"Error uploading file to MinIO: {str(e)}")
            return False
    
    def download_file(self, key: str, bucket: Optional[str] = None) -> Optional[bytes]:
        """Download file from MinIO"""
        try:
            bucket = bucket or self.data_bucket
            
            response = self.client.get_object(Bucket=bucket, Key=key)
            content = response['Body'].read()
            
            logger.info(f"Downloaded file from MinIO: s3://{bucket}/{key}")
            return content
            
        except Exception as e:
            logger.error(f"Error downloading file from MinIO: {str(e)}")
            return None
    
    def get_file_metadata(self, key: str, bucket: Optional[str] = None) -> Optional[Dict[str, Any]]:
        """Get file metadata from MinIO"""
        try:
            bucket = bucket or self.data_bucket
            
            response = self.client.head_object(Bucket=bucket, Key=key)
            
            return {
                'size': response['ContentLength'],
                'content_type': response.get('ContentType', 'application/octet-stream'),
                'last_modified': response['LastModified'].isoformat(),
                'metadata': response.get('Metadata', {}),
                'etag': response['ETag']
            }
            
        except Exception as e:
            logger.error(f"Error getting file metadata: {str(e)}")
            return None
    
    def delete_file(self, key: str, bucket: Optional[str] = None) -> bool:
        """Delete file from MinIO"""
        try:
            bucket = bucket or self.data_bucket
            
            self.client.delete_object(Bucket=bucket, Key=key)
            logger.info(f"Deleted file from MinIO: s3://{bucket}/{key}")
            return True
            
        except Exception as e:
            logger.error(f"Error deleting file from MinIO: {str(e)}")
            return False
    
    def list_files(self, prefix: str = '', bucket: Optional[str] = None, max_keys: int = 1000) -> List[Dict[str, Any]]:
        """List files in MinIO bucket"""
        try:
            bucket = bucket or self.data_bucket
            
            response = self.client.list_objects_v2(
                Bucket=bucket,
                Prefix=prefix,
                MaxKeys=max_keys
            )
            
            files = []
            for obj in response.get('Contents', []):
                files.append({
                    'key': obj['Key'],
                    'size': obj['Size'],
                    'last_modified': obj['LastModified'].isoformat(),
                    'etag': obj['ETag']
                })
            
            return files
            
        except Exception as e:
            logger.error(f"Error listing files in MinIO: {str(e)}")
            return []
    
    def get_presigned_url(self, key: str, bucket: Optional[str] = None, expiration: int = 3600) -> Optional[str]:
        """Generate presigned URL for file access"""
        try:
            bucket = bucket or self.data_bucket
            
            url = self.client.generate_presigned_url(
                'get_object',
                Params={'Bucket': bucket, 'Key': key},
                ExpiresIn=expiration
            )
            
            return url
            
        except Exception as e:
            logger.error(f"Error generating presigned URL: {str(e)}")
            return None
    
    def bucket_exists(self, bucket: str) -> bool:
        """Check if bucket exists"""
        try:
            self.client.head_bucket(Bucket=bucket)
            return True
        except ClientError:
            return False
    
    def get_bucket_size(self, bucket: Optional[str] = None) -> Dict[str, Any]:
        """Get bucket size statistics"""
        try:
            bucket = bucket or self.data_bucket
            
            response = self.client.list_objects_v2(Bucket=bucket)
            
            total_size = 0
            file_count = 0
            
            for obj in response.get('Contents', []):
                total_size += obj['Size']
                file_count += 1
            
            return {
                'bucket': bucket,
                'total_size_bytes': total_size,
                'total_size_mb': round(total_size / (1024 * 1024), 2),
                'file_count': file_count
            }
            
        except Exception as e:
            logger.error(f"Error getting bucket size: {str(e)}")
            return {'bucket': bucket, 'total_size_bytes': 0, 'file_count': 0}


