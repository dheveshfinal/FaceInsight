import os
import json
from loguru import logger
from typing import Dict, Any, List, TypedDict

# Langchain & Groq
from langchain_groq import ChatGroq
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import JsonOutputParser

# Qdrant
from qdrant_client import QdrantClient

# LangGraph
from langgraph.graph import StateGraph, START, END


# State for LangGraph
class AgentState(TypedDict):
    question: str
    context: str
    answer: str


class AIService:
    def __init__(self):
        self.groq_api_key = os.getenv("GROQ_API_KEY")
        self.qdrant_url = os.getenv("QDRANT_URL", "http://qdrant:6333")
        
        # Initialize Groq LLM
        if self.groq_api_key:
            self.llm = ChatGroq(
                temperature=0.7,
                model_name="llama-3.1-8b-instant",  # Use active Groq model for speed
                groq_api_key=self.groq_api_key
            )
        else:
            logger.warning("GROQ_API_KEY is not set. AIService will not function properly.")
            self.llm = None
            
        # Initialize Qdrant Client
        try:
            self.qdrant = QdrantClient(url=self.qdrant_url)
            logger.info("Connected to Qdrant successfully.")
        except Exception as e:
            logger.warning(f"Could not connect to Qdrant: {e}")
            self.qdrant = None

        # Build the RAG Graph
        self.rag_graph = self._build_rag_graph()

    def generate_suggestions(self, ml_outputs: Dict[str, Any]) -> Dict[str, Any]:
        """
        Takes raw ML numbers and uses Groq to generate formatted suggestions.
        """
        if not self.llm:
            return {"error": "LLM not configured"}

        logger.info("Generating suggestions via Groq...")
        
        prompt = ChatPromptTemplate.from_messages([
            ("system", "You are an expert dermatologist and aesthetician AI. A user just received their facial scan results: {ml_outputs}. Based strictly on these numbers, provide 3 actionable skincare suggestions and 2 lifestyle suggestions. Format the output in strict JSON with keys: 'skincare_suggestions' (list of strings) and 'lifestyle_suggestions' (list of strings)."),
            ("human", "Generate the recommendations.")
        ])
        
        parser = JsonOutputParser()
        chain = prompt | self.llm | parser
        
        try:
            result = chain.invoke({"ml_outputs": json.dumps(ml_outputs)})
            return result
        except Exception as e:
            logger.error(f"Failed to generate suggestions: {e}")
            return {"error": str(e)}

    # ── LangGraph RAG Pipeline ──────────────────────────────────────────────

    def _retrieve(self, state: AgentState) -> AgentState:
        """Retrieve context from Qdrant based on the question."""
        question = state["question"]
        logger.info(f"Retrieving context for: {question}")
        
        # NOTE: For a real RAG, you would embed the question and search Qdrant.
        # Since we haven't ingested documents yet, we return mock context.
        # Example Qdrant usage:
        # hits = self.qdrant.search(collection_name="skincare_docs", query_vector=embedded_question)
        
        mock_context = "Drink plenty of water and apply SPF 50 daily to protect skin texture and hydration."
        return {"context": mock_context}

    def _generate(self, state: AgentState) -> AgentState:
        """Generate answer using Groq based on the retrieved context."""
        question = state["question"]
        context = state["context"]
        
        if not self.llm:
            return {"answer": "LLM not configured"}
            
        logger.info("Generating RAG answer via Groq...")
        
        prompt = ChatPromptTemplate.from_messages([
            ("system", "You are a helpful AI skincare assistant. Answer the user's question based strictly on the following context:\n\n{context}"),
            ("human", "{question}")
        ])
        
        chain = prompt | self.llm
        
        try:
            response = chain.invoke({"context": context, "question": question})
            return {"answer": response.content}
        except Exception as e:
            logger.error(f"Failed to generate RAG answer: {e}")
            return {"answer": f"Error: {e}"}

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

    def chat_rag(self, user_question: str) -> str:
        """Entry point for the RAG chat."""
        initial_state = {"question": user_question, "context": "", "answer": ""}
        final_state = self.rag_graph.invoke(initial_state)
        return final_state["answer"]
