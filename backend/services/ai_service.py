import os
os.environ["HF_HOME"] = "/tmp/huggingface"
os.environ["TRANSFORMERS_CACHE"] = "/tmp/huggingface"

import json
import uuid
from datetime import datetime
from loguru import logger
from typing import Dict, Any, List, TypedDict, Optional

# Langchain & Groq
from langchain_groq import ChatGroq
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import JsonOutputParser

# Embeddings - fastembed (lightweight)
from fastembed import TextEmbedding

# Qdrant
from qdrant_client import QdrantClient
from qdrant_client.http.models import Distance, VectorParams, PointStruct, Filter, FieldCondition, MatchValue

# LangGraph
from langgraph.graph import StateGraph, START, END


# State for LangGraph
class AgentState(TypedDict):
    question: str
    context: str
    answer: str
    user_id: Optional[int]
    session_id: Optional[str]


COLLECTION_NAME = "skincare_recommendations"
VECTOR_SIZE = 384
EMBEDDING_MODEL = "BAAI/bge-small-en-v1.5"


class AIService:
    def __init__(self):
        self.groq_api_key = os.getenv("GROQ_API_KEY")
        self.qdrant_url = os.getenv("QDRANT_URL", "http://qdrant:6333")
        self.qdrant_api_key = os.getenv("QDRANT_API_KEY", "")  # For Qdrant Cloud
        
        # Initialize Groq LLM
        if self.groq_api_key:
            self.llm = ChatGroq(
                temperature=0.7,
                model_name="llama-3.1-8b-instant",
                groq_api_key=self.groq_api_key
            )
        else:
            logger.warning("GROQ_API_KEY is not set. AIService will not function properly.")
            self.llm = None
            
        # Initialize HuggingFace Sentence Transformer lazily to save memory on startup
        self.embeddings_model = None
        
    def _get_embeddings(self):
        if self.embeddings_model is None:
            try:
                logger.info(f"Loading embedding model: {EMBEDDING_MODEL}")
                self.embeddings_model = TextEmbedding(EMBEDDING_MODEL)
                logger.info("✅ Embeddings loaded successfully")
            except Exception as e:
                logger.error(f"Failed to load embeddings model: {e}")
        return self.embeddings_model
        # Initialize Qdrant Client
        try:
            # Support both local Qdrant and Qdrant Cloud
            if self.qdrant_api_key:
                # Qdrant Cloud with API key
                self.qdrant = QdrantClient(url=self.qdrant_url, api_key=self.qdrant_api_key)
            else:
                # Local Qdrant or Qdrant with no auth
                self.qdrant = QdrantClient(url=self.qdrant_url)
            logger.info("Connected to Qdrant successfully.")
            self._init_collection()
        except Exception as e:
            logger.warning(f"Could not connect to Qdrant: {e}")
            self.qdrant = None

        # Build the RAG Graph
        self.rag_graph = self._build_rag_graph()

    def _init_collection(self):
        """Initialize or create Qdrant collection for recommendations."""
        try:
            # Check if collection exists
            collections = self.qdrant.get_collections().collections
            collection_names = [c.name for c in collections]
            
            if COLLECTION_NAME not in collection_names:
                logger.info(f"Creating Qdrant collection: {COLLECTION_NAME}")
                self.qdrant.create_collection(
                    collection_name=COLLECTION_NAME,
                    vectors_config=VectorParams(size=VECTOR_SIZE, distance=Distance.COSINE)
                )
                logger.info(f"✅ Collection {COLLECTION_NAME} created successfully")
            else:
                logger.info(f"✅ Collection {COLLECTION_NAME} already exists")
        except Exception as e:
            logger.error(f"Failed to initialize collection: {e}")

    def generate_suggestions(self, ml_outputs: Dict[str, Any], user_id: Optional[int] = None, session_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Takes raw ML numbers and uses Groq to generate formatted suggestions.
        Stores recommendations in Qdrant for future RAG retrieval.
        """
        if not self.llm:
            return {"error": "LLM not configured"}

        logger.info(f"Generating suggestions via Groq for user_id={user_id}, session_id={session_id}")
        
        prompt = ChatPromptTemplate.from_messages([
            ("system", "You are an expert dermatologist and aesthetician AI. A user just received their facial scan results: {ml_outputs}. Based strictly on these numbers, provide 3 actionable skincare suggestions and 2 lifestyle suggestions. Format the output in strict JSON with keys: 'skincare_suggestions' (list of strings) and 'lifestyle_suggestions' (list of strings)."),
            ("human", "Generate the recommendations.")
        ])
        
        parser = JsonOutputParser()
        chain = prompt | self.llm | parser
        
        try:
            result = chain.invoke({"ml_outputs": json.dumps(ml_outputs)})
            
            # Store recommendations in Qdrant
            if user_id or session_id:
                self._store_recommendation(result, ml_outputs, user_id, session_id)
            
            return result
        except Exception as e:
            logger.error(f"Failed to generate suggestions: {e}")
            return {"error": str(e)}

    def _store_recommendation(self, suggestions: Dict[str, Any], ml_outputs: Dict[str, Any], user_id: Optional[int] = None, session_id: Optional[str] = None):
        """Store AI-generated recommendations in Qdrant with metadata."""
        embeddings_model = self._get_embeddings()
        if not self.qdrant or not embeddings_model:
            logger.warning("Cannot store recommendation: Qdrant or embeddings not available")
            return
        
        try:
            # Combine recommendations into single text for embedding
            rec_text = " ".join(suggestions.get("skincare_suggestions", [])) + " " + " ".join(suggestions.get("lifestyle_suggestions", []))
            
            # Generate embedding using HuggingFace
            embedding = list(embeddings_model.embed([rec_text]))[0].tolist()
            
            # Create unique point ID
            point_id = int(uuid.uuid4().int % (2**63))
            
            # Metadata for filtering by user/session
            payload = {
                "user_id": user_id if user_id else -1,  # -1 for anonymous
                "session_id": session_id or "unknown",
                "timestamp": datetime.utcnow().isoformat(),
                "recommendations": rec_text,
                "suggestions": json.dumps(suggestions),
                "ml_data": json.dumps(ml_outputs)
            }
            
            # Upsert to Qdrant
            self.qdrant.upsert(
                collection_name=COLLECTION_NAME,
                points=[
                    PointStruct(
                        id=point_id,
                        vector=embedding,
                        payload=payload
                    )
                ]
            )
            
            logger.info(f"✅ Recommendation stored in Qdrant (point_id={point_id})")
        except Exception as e:
            logger.error(f"Failed to store recommendation in Qdrant: {e}")

    # ── LangGraph RAG Pipeline ──────────────────────────────────────────────

    def _retrieve(self, state: AgentState) -> AgentState:
        """Retrieve context from Qdrant based on user's question."""
        question = state["question"]
        user_id = state.get("user_id")
        session_id = state.get("session_id")
        
        logger.info(f"Retrieving context for: {question} (user_id={user_id}, session_id={session_id})")
        
        context = ""
        
        embeddings_model = self._get_embeddings()
        if self.qdrant and embeddings_model:
            try:
                question_embedding = list(embeddings_model.embed([question]))[0].tolist()
                
                if user_id:
                    filter_condition = Filter(
                        must=[FieldCondition(key="user_id", match=MatchValue(value=user_id))]
                    )
                elif session_id:
                    filter_condition = Filter(
                        must=[FieldCondition(key="session_id", match=MatchValue(value=session_id))]
                    )
                else:
                    filter_condition = None
                
                hits = self.qdrant.search(
                    collection_name=COLLECTION_NAME,
                    query_vector=question_embedding,
                    query_filter=filter_condition,
                    limit=3,
                    score_threshold=0.5
                )
                
                if hits:
                    contexts = [hit.payload.get("recommendations", "") for hit in hits if hit.payload]
                    context = " ".join(contexts)
                    logger.info(f"✅ Retrieved {len(hits)} relevant recommendations from Qdrant")
                else:
                    context = "No previous recommendations found. Providing general skincare advice."
                    
            except Exception as e:
                logger.error(f"Failed to retrieve from Qdrant: {e}")
                context = "Unable to retrieve context. Providing general skincare advice."
        
        return {**state, "context": context}

    def _generate(self, state: AgentState) -> AgentState:
        """Generate answer using Groq based on retrieved context."""
        question = state["question"]
        context = state["context"]
        
        if not self.llm:
            return {**state, "answer": "LLM not configured"}
            
        logger.info("Generating RAG answer via Groq...")
        
        prompt = ChatPromptTemplate.from_messages([
            ("system", "You are a helpful AI skincare assistant. Answer the user's question based on their previous skincare recommendations and general skincare knowledge.\n\nTheir previous recommendations:\n{context}\n\nBe concise, actionable, and personalized."),
            ("human", "{question}")
        ])
        
        chain = prompt | self.llm
        
        try:
            response = chain.invoke({"context": context, "question": question})
            answer = response.content
            logger.info("✅ Generated RAG answer successfully")
            return {**state, "answer": answer}
        except Exception as e:
            logger.error(f"Failed to generate RAG answer: {e}")
            return {**state, "answer": f"Error generating response: {e}"}

    def _build_rag_graph(self):
        """Construct the LangGraph state machine for RAG."""
        workflow = StateGraph(AgentState)
        
        # Add nodes
        workflow.add_node("retrieve", self._retrieve)
        workflow.add_node("generate", self._generate)
        
        # Add edges
        workflow.add_edge(START, "retrieve")
        workflow.add_edge("retrieve", "generate")
        workflow.add_edge("generate", END)
        
        return workflow.compile()

    def chat_rag(self, user_question: str, user_id: Optional[int] = None, session_id: Optional[str] = None) -> str:
        """Entry point for the RAG chat - retrieves user's own recommendations."""
        initial_state = {
            "question": user_question,
            "context": "",
            "answer": "",
            "user_id": user_id,
            "session_id": session_id
        }
        final_state = self.rag_graph.invoke(initial_state)
        return final_state["answer"]

    def cleanup_session(self, session_id: str) -> bool:
        """Delete all recommendations for an anonymous session when app closes."""
        if not self.qdrant:
            logger.warning("Cannot cleanup session: Qdrant not available")
            return False
        
        try:
            # Delete all points with this session_id
            self.qdrant.delete(
                collection_name=COLLECTION_NAME,
                points_selector=Filter(
                    must=[
                        FieldCondition(key="session_id", match=MatchValue(value=session_id))
                    ]
                )
            )
            logger.info(f"✅ Cleaned up session data for session_id={session_id}")
            return True
        except Exception as e:
            logger.error(f"Failed to cleanup session: {e}")
            return False
