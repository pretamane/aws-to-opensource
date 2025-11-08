# Meilisearch Service - Replaces AWS OpenSearch
import os
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime
import meilisearch

logger = logging.getLogger(__name__)

class MeilisearchService:
    """Meilisearch service replacing AWS OpenSearch"""
    
    def __init__(self):
        self.url = os.environ.get('MEILISEARCH_URL', 'http://meilisearch:7700')
        self.api_key = os.environ.get('MEILISEARCH_API_KEY')
        
        if not self.api_key:
            raise ValueError("MEILISEARCH_API_KEY environment variable not set")
        
        self.client = meilisearch.Client(self.url, self.api_key)
        self.index_name = os.environ.get('MEILISEARCH_INDEX', 'documents')
        self._index = None
        
        logger.info(f"Meilisearch client initialized: {self.url}")
    
    def get_index(self):
        """Get or create Meilisearch index"""
        if self._index is None:
            try:
                self._index = self.client.get_index(self.index_name)
                logger.info(f"Using existing index: {self.index_name}")
            except Exception:
                # Index doesn't exist, create it
                self.create_index()
        return self._index
    
    def create_index(self) -> bool:
        """Create Meilisearch index with configuration"""
        try:
            # Create index
            task = self.client.create_index(self.index_name, {'primaryKey': 'id'})
            self.client.wait_for_task(task['taskUid'])
            
            self._index = self.client.get_index(self.index_name)
            
            # Configure searchable attributes
            self._index.update_searchable_attributes([
                'filename',
                'text_content',
                'content',
                'document_type',
                'keywords',
                'description'
            ])
            
            # Configure filterable attributes
            self._index.update_filterable_attributes([
                'contact_id',
                'document_type',
                'processing_status',
                'upload_timestamp',
                'file_extension'
            ])
            
            # Configure sortable attributes
            self._index.update_sortable_attributes([
                'upload_timestamp',
                'processing_timestamp',
                'complexity_score'
            ])
            
            # Configure ranking rules
            self._index.update_ranking_rules([
                'words',
                'typo',
                'proximity',
                'attribute',
                'sort',
                'exactness'
            ])
            
            logger.info(f"Created and configured index: {self.index_name}")
            return True
            
        except Exception as e:
            logger.error(f"Error creating Meilisearch index: {str(e)}")
            return False
    
    def index_document(self, document: Dict[str, Any]) -> bool:
        """Index document in Meilisearch (replaces OpenSearch index)"""
        try:
            index = self.get_index()
            
            # Prepare document for Meilisearch
            # Flatten nested structures for better searching
            meili_document = {
                'id': document['id'],
                'contact_id': document['contact_id'],
                'filename': document['filename'],
                'document_type': document['document_type'],
                'content': document.get('content', ''),
                'text_content': document.get('text_content', ''),
                'upload_timestamp': document['upload_timestamp'],
                'processing_timestamp': document.get('processing_timestamp', ''),
                
                # Flatten metadata for searching
                'word_count': document.get('metadata', {}).get('word_count', 0),
                'character_count': document.get('metadata', {}).get('character_count', 0),
                'file_extension': document.get('metadata', {}).get('file_extension', ''),
                'language_detected': document.get('metadata', {}).get('language_detected', 'en'),
                'keywords': document.get('metadata', {}).get('keywords', []),
                
                # Processing info
                'processing_status': document.get('processing_info', {}).get('status', 'unknown'),
                'complexity_score': document.get('processing_info', {}).get('complexity_score', 0.0),
                
                # S3 metadata
                's3_bucket': document.get('s3_metadata', {}).get('bucket', ''),
                's3_key': document.get('s3_metadata', {}).get('key', ''),
                'size': document.get('s3_metadata', {}).get('size', 0),
            }
            
            # Add document
            task = index.add_documents([meili_document])
            self.client.wait_for_task(task['taskUid'])
            
            logger.info(f"Indexed document in Meilisearch: {document['id']}")
            return True
            
        except Exception as e:
            logger.error(f"Error indexing document: {str(e)}")
            return False
    
    def search_documents(self, query: str, filters: Optional[Dict] = None, limit: int = 10) -> Dict[str, Any]:
        """Search documents in Meilisearch (replaces OpenSearch search)"""
        try:
            index = self.get_index()
            
            # Build search options
            search_options = {
                'limit': limit,
                'attributesToRetrieve': [
                    'id', 'contact_id', 'filename', 'document_type',
                    'text_content', 'upload_timestamp', 'processing_status',
                    'complexity_score', 'keywords', 'size'
                ],
                'attributesToHighlight': ['filename', 'text_content'],
                'sort': ['upload_timestamp:desc']
            }
            
            # Add filters if provided
            if filters:
                filter_clauses = []
                for key, value in filters.items():
                    if isinstance(value, str):
                        filter_clauses.append(f'{key} = "{value}"')
                    else:
                        filter_clauses.append(f'{key} = {value}')
                
                if filter_clauses:
                    search_options['filter'] = ' AND '.join(filter_clauses)
            
            # Execute search
            start_time = datetime.utcnow()
            results = index.search(query, search_options)
            processing_time = (datetime.utcnow() - start_time).total_seconds()
            
            # Format results
            formatted_results = []
            for hit in results['hits']:
                formatted_results.append({
                    'document_id': hit['id'],
                    'filename': hit['filename'],
                    'contact_id': hit['contact_id'],
                    'document_type': hit['document_type'],
                    'text_content': hit.get('text_content', ''),
                    'upload_timestamp': hit['upload_timestamp'],
                    'processing_status': hit.get('processing_status', 'unknown'),
                    'score': 1.0  # Meilisearch doesn't expose scores by default
                })
            
            return {
                'results': formatted_results,
                'total_count': results['estimatedTotalHits'],
                'query': query,
                'processing_time': processing_time
            }
            
        except Exception as e:
            logger.error(f"Error searching documents: {str(e)}")
            return {'results': [], 'total_count': 0, 'query': query, 'processing_time': 0.0}
    
    def get_document_by_id(self, document_id: str) -> Optional[Dict[str, Any]]:
        """Get document by ID from Meilisearch"""
        try:
            index = self.get_index()
            document = index.get_document(document_id)
            return document
            
        except Exception as e:
            logger.error(f"Error getting document by ID: {str(e)}")
            return None
    
    def delete_document(self, document_id: str) -> bool:
        """Delete document from Meilisearch"""
        try:
            index = self.get_index()
            task = index.delete_document(document_id)
            self.client.wait_for_task(task['taskUid'])
            
            logger.info(f"Deleted document from index: {document_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error deleting document: {str(e)}")
            return False
    
    def get_index_stats(self) -> Dict[str, Any]:
        """Get index statistics"""
        try:
            index = self.get_index()
            stats = index.get_stats()
            
            return {
                'total_documents': stats['numberOfDocuments'],
                'is_indexing': stats['isIndexing'],
                'last_update': datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error getting index stats: {str(e)}")
            return {}




