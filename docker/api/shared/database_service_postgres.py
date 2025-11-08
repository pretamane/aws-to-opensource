# PostgreSQL Database Service - Replaces DynamoDB
import os
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime
import psycopg2
from psycopg2.extras import RealDictCursor, Json
from psycopg2.pool import SimpleConnectionPool

logger = logging.getLogger(__name__)

class PostgreSQLService:
    """PostgreSQL database service replacing DynamoDB"""
    
    def __init__(self):
        # Get connection parameters individually to avoid URL encoding issues
        self.db_host = os.environ.get('DB_HOST', 'postgresql')
        self.db_port = os.environ.get('DB_PORT', '5432')
        self.db_name = os.environ.get('DB_NAME', 'pretamane_db')
        self.db_user = os.environ.get('DB_USER', 'app_user')
        self.db_password = os.environ.get('DB_PASSWORD')
        
        if not self.db_password:
            raise ValueError("DB_PASSWORD environment variable not set")
        
        # Connection pool with individual parameters (avoids URL encoding issues)
        self.pool = SimpleConnectionPool(
            minconn=1,
            maxconn=10,
            host=self.db_host,
            port=self.db_port,
            database=self.db_name,
            user=self.db_user,
            password=self.db_password
        )
        
        logger.info("PostgreSQL connection pool initialized")
    
    def get_connection(self):
        """Get connection from pool"""
        return self.pool.getconn()
    
    def return_connection(self, conn):
        """Return connection to pool"""
        self.pool.putconn(conn)
    
    def create_contact_record(self, contact_data: Dict[str, Any]) -> str:
        """Create contact record (replaces DynamoDB put_item)"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            
            cur.execute("""
                INSERT INTO contact_submissions (
                    id, name, email, company, service, budget, message,
                    timestamp, status, source, user_agent, page_url,
                    document_processing_enabled, search_capabilities
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                )
                RETURNING id
            """, (
                contact_data['id'],
                contact_data['name'],
                contact_data['email'],
                contact_data.get('company', ''),
                contact_data.get('service', ''),
                contact_data.get('budget', ''),
                contact_data['message'],
                contact_data['timestamp'],
                contact_data.get('status', 'new'),
                contact_data.get('source', 'website'),
                contact_data.get('userAgent', ''),
                contact_data.get('pageUrl', ''),
                contact_data.get('document_processing_enabled', True),
                contact_data.get('search_capabilities', True)
            ))
            
            contact_id = cur.fetchone()[0]
            conn.commit()
            
            logger.info(f"Created contact record: {contact_id}")
            return contact_id
            
        except Exception as e:
            if conn:
                conn.rollback()
            logger.error(f"Error creating contact record: {str(e)}")
            raise
        finally:
            if conn:
                cur.close()
                self.return_connection(conn)
    
    def update_visitor_count(self) -> int:
        """Update visitor counter (replaces DynamoDB atomic counter)"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            
            cur.execute("SELECT increment_visitor_count()")
            visitor_count = cur.fetchone()[0]
            conn.commit()
            
            return visitor_count
            
        except Exception as e:
            if conn:
                conn.rollback()
            logger.error(f"Error updating visitor count: {str(e)}")
            return 0
        finally:
            if conn:
                cur.close()
                self.return_connection(conn)
    
    def get_visitor_count(self) -> int:
        """Get current visitor count"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            
            cur.execute("SELECT count FROM website_visitors WHERE id = 'visitor_count'")
            result = cur.fetchone()
            
            return result[0] if result else 0
            
        except Exception as e:
            logger.error(f"Error getting visitor count: {str(e)}")
            return 0
        finally:
            if conn:
                cur.close()
                self.return_connection(conn)
    
    def create_document_record(self, document_data: Dict[str, Any]) -> str:
        """Create document record (replaces DynamoDB put_item)"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            
            cur.execute("""
                INSERT INTO documents (
                    id, contact_id, filename, size, content_type, document_type,
                    description, tags, upload_timestamp, processing_status,
                    s3_bucket, s3_key, efs_path, file_hash
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                )
                RETURNING id
            """, (
                document_data['id'],
                document_data['contact_id'],
                document_data['filename'],
                document_data['size'],
                document_data['content_type'],
                document_data['document_type'],
                document_data.get('description', ''),
                Json(document_data.get('tags', [])),
                document_data['upload_timestamp'],
                document_data.get('processing_status', 'pending'),
                document_data.get('s3_bucket', ''),
                document_data.get('s3_key', ''),
                document_data.get('efs_path', ''),
                document_data.get('file_hash', '')
            ))
            
            document_id = cur.fetchone()[0]
            conn.commit()
            
            logger.info(f"Created document record: {document_id}")
            return str(document_id)
            
        except Exception as e:
            if conn:
                conn.rollback()
            logger.error(f"Error creating document record: {str(e)}")
            raise
        finally:
            if conn:
                cur.close()
                self.return_connection(conn)
    
    def update_document_status(self, document_id: str, status: str, metadata: Optional[Dict] = None) -> bool:
        """Update document processing status"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            
            if metadata:
                cur.execute("""
                    UPDATE documents 
                    SET processing_status = %s,
                        processing_timestamp = %s,
                        processing_metadata = %s
                    WHERE id = %s
                """, (status, datetime.utcnow(), Json(metadata), document_id))
            else:
                cur.execute("""
                    UPDATE documents 
                    SET processing_status = %s,
                        processing_timestamp = %s
                    WHERE id = %s
                """, (status, datetime.utcnow(), document_id))
            
            conn.commit()
            logger.info(f"Updated document {document_id} status to {status}")
            return True
            
        except Exception as e:
            if conn:
                conn.rollback()
            logger.error(f"Error updating document status: {str(e)}")
            return False
        finally:
            if conn:
                cur.close()
                self.return_connection(conn)
    
    def get_contact_documents(self, contact_id: str) -> List[Dict[str, Any]]:
        """Get all documents for a contact"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor(cursor_factory=RealDictCursor)
            
            cur.execute("""
                SELECT 
                    id as document_id,
                    filename,
                    document_type,
                    description,
                    tags,
                    upload_timestamp,
                    processing_status,
                    size
                FROM documents
                WHERE contact_id = %s
                ORDER BY upload_timestamp DESC
            """, (contact_id,))
            
            documents = cur.fetchall()
            return [dict(doc) for doc in documents]
            
        except Exception as e:
            logger.error(f"Error getting contact documents: {str(e)}")
            return []
        finally:
            if conn:
                cur.close()
                self.return_connection(conn)
    
    def enrich_contact_data(self, contact_id: str, document_metadata: Dict[str, Any]) -> Dict[str, Any]:
        """Enrich contact data with document insights"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor(cursor_factory=RealDictCursor)
            
            # Calculate insights
            document_insights = {
                'total_documents': 1,
                'document_types': [document_metadata.get('document_type', 'unknown')],
                'total_size': document_metadata.get('size', 0),
                'last_document_upload': document_metadata.get('upload_timestamp'),
                'processing_status': document_metadata.get('processing_status', 'pending'),
                'content_analysis': {
                    'has_business_content': document_metadata.get('has_business_keywords', False),
                    'complexity_score': self._calculate_complexity_score(document_metadata),
                    'confidence_level': 'high' if document_metadata.get('word_count', 0) > 100 else 'medium'
                }
            }
            
            # Update contact with insights
            cur.execute("""
                UPDATE contact_submissions 
                SET document_insights = %s,
                    last_updated = %s
                WHERE id = %s
            """, (Json(document_insights), datetime.utcnow(), contact_id))
            
            conn.commit()
            logger.info(f"Enriched contact {contact_id} with document insights")
            return document_insights
            
        except Exception as e:
            if conn:
                conn.rollback()
            logger.error(f"Error enriching contact data: {str(e)}")
            return {}
        finally:
            if conn:
                cur.close()
                self.return_connection(conn)
    
    def search_documents(self, query: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Search documents using PostgreSQL full-text search"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor(cursor_factory=RealDictCursor)
            
            cur.execute("""
                SELECT 
                    id as document_id,
                    filename,
                    contact_id,
                    document_type,
                    description,
                    tags,
                    upload_timestamp,
                    processing_status,
                    size
                FROM documents
                WHERE 
                    filename ILIKE %s OR
                    description ILIKE %s OR
                    document_type ILIKE %s
                ORDER BY upload_timestamp DESC
                LIMIT %s
            """, (f'%{query}%', f'%{query}%', f'%{query}%', limit))
            
            documents = cur.fetchall()
            return [dict(doc) for doc in documents]
            
        except Exception as e:
            logger.error(f"Error searching documents: {str(e)}")
            return []
        finally:
            if conn:
                cur.close()
                self.return_connection(conn)
    
    def get_analytics_data(self) -> Dict[str, Any]:
        """Get system analytics (replaces DynamoDB scan)"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor(cursor_factory=RealDictCursor)
            
            # Get contact count
            cur.execute("SELECT COUNT(*) as count FROM contact_submissions")
            total_contacts = cur.fetchone()['count']
            
            # Get document statistics
            cur.execute("""
                SELECT 
                    COUNT(*) as total_documents,
                    COUNT(CASE WHEN processing_status = 'pending' THEN 1 END) as pending,
                    COUNT(CASE WHEN processing_status = 'processing' THEN 1 END) as processing,
                    COUNT(CASE WHEN processing_status = 'completed' THEN 1 END) as completed,
                    COUNT(CASE WHEN processing_status = 'failed' THEN 1 END) as failed
                FROM documents
            """)
            doc_stats = cur.fetchone()
            
            # Get document types
            cur.execute("""
                SELECT document_type, COUNT(*) as count
                FROM documents
                GROUP BY document_type
            """)
            doc_types = {row['document_type']: row['count'] for row in cur.fetchall()}
            
            return {
                'total_contacts': total_contacts,
                'total_documents': doc_stats['total_documents'],
                'document_types': doc_types,
                'processing_stats': {
                    'pending': doc_stats['pending'],
                    'processing': doc_stats['processing'],
                    'completed': doc_stats['completed'],
                    'failed': doc_stats['failed']
                },
                'timestamp': datetime.utcnow().isoformat() + 'Z'
            }
            
        except Exception as e:
            logger.error(f"Error getting analytics data: {str(e)}")
            return {
                'total_contacts': 0,
                'total_documents': 0,
                'document_types': {},
                'processing_stats': {},
                'timestamp': datetime.utcnow().isoformat() + 'Z'
            }
        finally:
            if conn:
                cur.close()
                self.return_connection(conn)
    
    def _calculate_complexity_score(self, metadata: Dict[str, Any]) -> float:
        """Calculate document complexity score"""
        score = 0.0
        
        # Word count factor
        word_count = metadata.get('word_count', 0)
        if word_count > 1000:
            score += 0.3
        elif word_count > 500:
            score += 0.2
        elif word_count > 100:
            score += 0.1
        
        # Entity richness
        entities = metadata.get('entities', {})
        entity_count = sum(len(v) for v in entities.values())
        if entity_count > 10:
            score += 0.3
        elif entity_count > 5:
            score += 0.2
        elif entity_count > 0:
            score += 0.1
        
        # Keyword diversity
        keywords = metadata.get('keywords', [])
        if len(keywords) > 10:
            score += 0.2
        elif len(keywords) > 5:
            score += 0.1
        
        # File type complexity
        file_ext = metadata.get('file_extension', '')
        if file_ext in ['.pdf', '.docx', '.pptx']:
            score += 0.2
        elif file_ext in ['.doc', '.xlsx']:
            score += 0.1
        
        return min(score, 1.0)
    
    def close(self):
        """Close all connections in pool"""
        if self.pool:
            self.pool.closeall()
            logger.info("PostgreSQL connection pool closed")




