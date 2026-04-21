# -*- coding: utf-8 -*-
"""
SLM Lab — Backend API
FastAPI server that loads a Gemma model once and exposes a /api/generate endpoint
running the full translate-in → generate → translate-out pipeline.

Requirements:
  pip install -r requirements.txt

Environment variables:
  HF_TOKEN   — Your Hugging Face access token (required; Gemma is a gated model).
                Get one at https://huggingface.co/settings/tokens after accepting
                the Gemma terms at https://huggingface.co/google/gemma-1.1-2b-it

Run:
  uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"""

import os
import torch
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from transformers import AutoTokenizer, AutoModelForCausalLM
from deep_translator import GoogleTranslator


# ---------------------------------------------------------------------------
# Language registry
# ---------------------------------------------------------------------------

LANGUAGES: dict[str, str] = {
    "Bengali":   "bn",
    "Hindi":     "hi",
    "Tamil":     "ta",
    "Telugu":    "te",
    "Marathi":   "mr",
    "Gujarati":  "gu",
    "Punjabi":   "pa",
    "Urdu":      "ur",
    "Malayalam": "ml",
    "Kannada":   "kn",
    "Odia":      "or",
    "Assamese":  "as",
}


# ---------------------------------------------------------------------------
# Global model state
# ---------------------------------------------------------------------------

_model: Optional[AutoModelForCausalLM] = None
_tokenizer: Optional[AutoTokenizer] = None


def _load_model() -> None:
    global _model, _tokenizer

    model_id = os.environ.get("MODEL_ID", "google/gemma-1.1-2b-it")
    hf_token = os.environ.get("HF_TOKEN")

    if not hf_token:
        raise RuntimeError(
            "HF_TOKEN environment variable is not set. "
            "Gemma is a gated model — set your Hugging Face token before starting the server."
        )

    print(f"[SLM Lab] Loading tokenizer for '{model_id}' …")
    _tokenizer = AutoTokenizer.from_pretrained(model_id, token=hf_token)

    print(f"[SLM Lab] Loading model for '{model_id}' (this may take a few minutes) …")
    _model = AutoModelForCausalLM.from_pretrained(
        model_id,
        torch_dtype=torch.bfloat16,
        device_map="auto",
        token=hf_token,
    )
    print("[SLM Lab] Model loaded successfully ✓")


# ---------------------------------------------------------------------------
# FastAPI lifespan (load model on startup, release on shutdown)
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    _load_model()
    yield
    # Release GPU memory on shutdown
    global _model, _tokenizer
    del _model, _tokenizer
    if torch.cuda.is_available():
        torch.cuda.empty_cache()


# ---------------------------------------------------------------------------
# App definition
# ---------------------------------------------------------------------------

app = FastAPI(
    title="SLM Lab API",
    description="Low-resource language benchmarking via Gemma + translation pipeline.",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # tighten for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class GenerateRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=2000, description="Input text in the chosen language.")
    language: str = Field(..., description="Language name, e.g. 'Bengali'.")
    max_new_tokens: int = Field(512, ge=64, le=1024)
    temperature: float = Field(0.7, ge=0.1, le=2.0)


class GenerateResponse(BaseModel):
    language: str
    lang_code: str
    english_query: str
    english_response: str
    translated_response: str


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    supported_languages: list[str]


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@app.get("/health", response_model=HealthResponse, tags=["utility"])
def health_check():
    """Ping endpoint — returns model status and supported languages."""
    return HealthResponse(
        status="ok",
        model_loaded=_model is not None,
        supported_languages=sorted(LANGUAGES.keys()),
    )


@app.get("/languages", tags=["utility"])
def list_languages():
    """Return all supported languages with their ISO 639-1 codes."""
    return [{"name": k, "code": v} for k, v in sorted(LANGUAGES.items())]


@app.post("/api/generate", response_model=GenerateResponse, tags=["inference"])
def generate(req: GenerateRequest):
    """
    Full pipeline:
      1. Translate input from `language` → English   (deep-translator / Google Translate)
      2. Feed translated query to Gemma               (local model)
      3. Translate Gemma's English response → `language`
    """
    if _model is None or _tokenizer is None:
        raise HTTPException(status_code=503, detail="Model is not loaded yet. Please wait and retry.")

    lang_code = LANGUAGES.get(req.language)
    if not lang_code:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported language '{req.language}'. "
                   f"Supported: {', '.join(sorted(LANGUAGES.keys()))}",
        )

    try:
        # ── Step 1: Translate input → English ──────────────────────────────
        english_query: str = GoogleTranslator(source=lang_code, target="en").translate(req.text)

        # ── Step 2: Run Gemma ───────────────────────────────────────────────
        chat = [{"role": "user", "content": english_query}]
        prompt = _tokenizer.apply_chat_template(
            chat, tokenize=False, add_generation_prompt=True
        )
        inputs = _tokenizer.encode(
            prompt, add_special_tokens=False, return_tensors="pt"
        ).to(_model.device)

        with torch.no_grad():
            outputs = _model.generate(
                inputs,
                max_new_tokens=req.max_new_tokens,
                do_sample=True,
                temperature=req.temperature,
            )

        generated_tokens = outputs[0][inputs.shape[1]:]
        english_response: str = _tokenizer.decode(generated_tokens, skip_special_tokens=True)

        # ── Step 3: Translate response → original language ─────────────────
        # deep-translator caps at ~5000 chars per request; chunking handles longer outputs.
        translated_response = _translate_long(english_response, source="en", target=lang_code)

        return GenerateResponse(
            language=req.language,
            lang_code=lang_code,
            english_query=english_query,
            english_response=english_response,
            translated_response=translated_response,
        )

    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _translate_long(text: str, source: str, target: str, chunk_size: int = 4500) -> str:
    """Translate potentially long text by splitting into chunks."""
    if len(text) <= chunk_size:
        return GoogleTranslator(source=source, target=target).translate(text)

    # Split on sentence boundaries where possible
    sentences = text.replace("\n", " \n ").split(". ")
    chunks: list[str] = []
    current = ""

    for sentence in sentences:
        if len(current) + len(sentence) < chunk_size:
            current += sentence + ". "
        else:
            if current:
                chunks.append(current.strip())
            current = sentence + ". "
    if current:
        chunks.append(current.strip())

    translated_chunks = [
        GoogleTranslator(source=source, target=target).translate(c)
        for c in chunks
    ]
    return " ".join(translated_chunks)
